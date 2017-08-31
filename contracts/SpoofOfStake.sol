pragma solidity ^0.4.13;

contract SpoofOfStakeBeta{


  /*
  * SAFE MATH LIBRARY:
  */
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  /*
  * STRUCTS:
  */

  /*
  * Allows for a mapping between a user's address, and the amounts they have
  * contributed to both sides of the game
  */
  struct BackingAmt{
    uint amtA;
    uint amtB;
  }

  //Represents a single Game period
  struct Game{
    //For access and Ether withdrawal from previous games
    uint gameId;
    //Keeps track of every backer for this game
    mapping(address => BackingAmt) backers;

    uint startTime;
    uint endTime;

    //Keeps track of the overall amounts sent to A and B
    //Remains constant after a game is finished
    uint totalInA;
    uint totalInB;

    //Keeps track of the total Ether the game holds. Changes based on
    //withdrawals after a game. Is calculated post-game
    uint totalInGame;

    //0 - In progress, 1 - A won, 2 - B won, 3 - Tie
    uint8 winner;

    //Keeps track of this game's house cut and bounty percentages, so that
    //In the event of a vote to change any of these, they remain the same
    //for the current game.
    uint current_house_cut;
    uint current_house_cut_tie;
    uint current_bounty;
  }

  /*
  * CONTRACT VARIABLES:
  */

  //The current running game's id
  uint curGameId;
  //Mapping of all gameIds to their respective games
  mapping(uint => Game) games;
  //privileged address - allows the token contract to interact
  address public privileged;
  //Amount of Ether taken from house edge and not withdrawn from the contract
  uint public treasury;

  bool public paused;

  uint public gameDur;

  //The amount of time during which the game time will be extended if a bet is placed
  //within this amount of the endTime of the game
  uint public bufferTime;

  //If we need to extend the game, we add this amount
  uint public timeAdd;

  uint public house_cut_percent;
  uint public house_cut_percent_tie;

  //Percent of the house_cut received by anyone who calls startNewGame when
  //there is no current running game
  uint public startgame_bounty_percent;

  //Defined so no magic constants are used
  uint8 public constant IN_PROGRESS = 0;
  uint8 public constant SIDE_A = 1;
  uint8 public constant SIDE_B = 2;
  uint8 public constant TIE = 3;


  //Constructor
  function SpoofOfStakeBeta(){
    privileged = msg.sender;
    paused = false;
    gameDur = 2 minutes;
    games[0] = Game({
      gameId:0,
      startTime:now,
      endTime: add(now, gameDur),
      totalInA:0,
      totalInB:0,
      totalInGame:0,
      winner:IN_PROGRESS,
      current_house_cut:5,
      current_house_cut_tie:10,
      current_bounty:1
    });
    bufferTime = 1 minutes;
    timeAdd = 5 minutes;
    curGameId = 0;
    house_cut_percent = 5;
    house_cut_percent_tie = 10;
    startgame_bounty_percent = 1;
  }

  /*
  * MODIFIERS:
  */

  //Throws if there is not an active game
  modifier activeGameExists(){
    require(now <= games[curGameId].endTime);
    _;
  }

  //Throws if there is an active game
  modifier noActiveGameExists(){
    require(now > games[curGameId].endTime);
    _;
  }

  //Throws if the gameId provided pertains to a game in session
  modifier notRunning(uint gameId){
    require(now > games[gameId].endTime);
    _;
  }

  modifier validSideChoice(uint8 choice){
    require(choice == SIDE_A || choice == SIDE_B);
    _;
  }

  modifier notPaused(){
    require(paused == false);
    _;
  }

  modifier onlyPrivileged(){
    require(msg.sender == privileged);
    _;
  }

  /*
  * EVENTS:
  */

  //Event displays a user backing a side
  event LogBack(address sender, string choice, uint value);

  //Event displays amounts added to the treasury
  event HouseCut(uint cut_amount, uint cut_percent, uint treasury_amt);

  //Event displays the start of a new game
  event NewGame(uint indexed startTime, uint indexed endTime);

  //Event displays a payment to a winner
  event PaidOut(uint amt_paid, uint indexed gameId, address _to);

  /*
  * Functions for privileged address:
  */
  function pause() onlyPrivileged {
    paused = true;
  }

  function unpause() onlyPrivileged {
    paused = false;
  }

  function newPrivileged(address new_privileged_address) onlyPrivileged {
    privileged = new_privileged_address;
  }

  function setHouseCut(uint house_cut) onlyPrivileged {
    house_cut_percent = house_cut;
  }

  function setHouseCutTie(uint house_cut_tie) onlyPrivileged {
    house_cut_percent_tie = house_cut_tie;
  }

  //Used by the token contract to withdraw treasury
  function withdrawTreasury() onlyPrivileged {
    uint temp = treasury;
    treasury = 0;
    msg.sender.transfer(temp);
  }

  function setBufferTime(uint time) onlyPrivileged{
    bufferTime = time;
  }

  function setTimeAdd(uint time) onlyPrivileged{
    timeAdd = time;
  }

  //Allows a player to back a side - A or B by calling this function
  //and passing in an integer indicating the side choice.
  //Accepted integers: 1 or 2, to represent sides A and B respectively
  function back(uint8 choice)
    activeGameExists
    validSideChoice(choice)
    notPaused
    payable
    returns(bool success)
    {
    if(choice == 1){ //User backs side A
      //If the current game will end soon, we want to extend the game to prevent a miner
      //from submitting the final bet
      if(games[curGameId].endTime - bufferTime < now){
        games[curGameId].endTime = add(games[curGameId].endTime, timeAdd);
      }
      games[curGameId].totalInA = add(games[curGameId].totalInA,  msg.value);
      games[curGameId].backers[msg.sender].amtA =
          add(games[curGameId].backers[msg.sender].amtA,  msg.value);
      LogBack(msg.sender, "A", msg.value);
      return true;
    } else if (choice == 2){ //User backs side B
      //If the current game will end soon, we want to extend the game to prevent a miner
      //from submitting the final bet
      if(games[curGameId].endTime - bufferTime < now){
        games[curGameId].endTime = add(games[curGameId].endTime, timeAdd);
      }
      games[curGameId].totalInB = add(games[curGameId].totalInB,  msg.value);
      games[curGameId].backers[msg.sender].amtB =
          add(games[curGameId].backers[msg.sender].amtB,  msg.value);
      LogBack(msg.sender, "B", msg.value);
      return true;
    } else { //No choice, or an invalid choice was made
      //This should never be accessed, because of the validSideChoice modifier
      return false;
    }
  }

  //Create a new game if there is no game running
  //The person who calls this function will receive a bounty equal to a portion
  //of the house cut from this game as a reward
  function startGame()
    noActiveGameExists
    notPaused
    returns(bool success)
    {

    //To save on gas, if the previous game had no ether in it, we simply
    //extend the endTime and return. Unfortunately in this case there is no
    //bounty for the sender but the gas cost is also low
    if(games[curGameId].totalInA == 0 && games[curGameId].totalInB == 0){
      games[curGameId].endTime = add(games[curGameId].endTime, gameDur);
      return true;
    } else {
      //Calculating the total Ether in this game
      games[curGameId].totalInGame =
          add(games[curGameId].totalInA, games[curGameId].totalInB);
    }

    //Decide the winner based on amounts in A and B
    if(games[curGameId].totalInA < games[curGameId].totalInB){
      games[curGameId].winner = SIDE_A;
    } else if (games[curGameId].totalInB < games[curGameId].totalInA){
      games[curGameId].winner = SIDE_B;
    } else {
      games[curGameId].winner = TIE;
    }

    //If either side didn't have any bets placed, we want to give refunds to anyone that bet
    //So, we create a new game without taking a house cut
    if(games[curGameId].totalInA == 0 || games[curGameId].totalInB == 0){
      curGameId = add(curGameId, 1);
      games[curGameId] = Game({
        startTime: now,
        endTime: add(now, gameDur),
        gameId: curGameId,
        totalInA: 0,
        totalInB: 0,
        totalInGame: 0,
        winner: IN_PROGRESS,
        current_house_cut:house_cut_percent,
        current_house_cut_tie:house_cut_percent_tie,
        current_bounty:startgame_bounty_percent
      });

      NewGame(games[curGameId].startTime, games[curGameId].endTime);

      return true;
    }

    uint house_cut = 0;
    uint bounty = 0;

    //House cut is different if the game is a tie
    //Using SafeMath reduces readability in this case - but the house cut should never overflow
    if(games[curGameId].winner == TIE){
      house_cut += (games[curGameId].totalInGame * games[curGameId].current_house_cut_tie) / 100;
    } else {
      house_cut += (games[curGameId].totalInGame * games[curGameId].current_house_cut) / 100;
    }

    games[curGameId].totalInGame = sub(games[curGameId].totalInGame, house_cut);
    bounty = add(bounty, (house_cut * games[curGameId].current_bounty) / 100);
    house_cut = sub(house_cut, bounty);
    treasury = add(treasury, house_cut);

    //Now increment curGameId and create a new game
    curGameId = add(curGameId, 1);
    games[curGameId] = Game({
      startTime: now,
      endTime: add(now, gameDur),
      gameId: curGameId,
      totalInA: 0,
      totalInB: 0,
      totalInGame: 0,
      winner: IN_PROGRESS,
      current_house_cut:house_cut_percent,
      current_house_cut_tie:house_cut_percent_tie,
      current_bounty:startgame_bounty_percent
    });

    //Attempt to send the person who called this function the bounty
    msg.sender.transfer(bounty);

    NewGame(games[curGameId].startTime, games[curGameId].endTime);

    return true;

  }

  /*
  * Once a game is complete, winnings can be withdrawn. This will fail
  * if the game is still running or if there is not a current game running,
  * to prevent withdrawals from the previous game if the startGame function
  * has not been called
  * gameId: The id of the game to withdraw from
  */
  function withdrawWinnings(uint gameId)
    notRunning(gameId)
    activeGameExists
    notPaused
    returns (bool success)
    {
    //if side A won
    uint amount_to_withdraw = 0;
    if(games[gameId].winner == SIDE_A){
      //If msg.sender did not contribute to side A, or has already withdrawn
      if(games[gameId].backers[msg.sender].amtA == 0){
        return false;
      }

      //If no one submitted a bet to the other side, issue a refund
      if(games[gameId].totalInA == 0
        && games[gameId].backers[msg.sender].amtB != 0){

        amount_to_withdraw = games[gameId].backers[msg.sender].amtB;
        games[gameId].totalInGame =
            sub(games[gameId].totalInGame, amount_to_withdraw);
        delete games[gameId].backers[msg.sender];
        msg.sender.transfer(amount_to_withdraw);
        return true;
      }

      amount_to_withdraw =
          add(amount_to_withdraw, games[gameId].backers[msg.sender].amtA);

      amount_to_withdraw += ((games[gameId].backers[msg.sender].amtA
              * games[gameId].totalInB) / games[gameId].totalInA);
      //Takes out the house cut, but does not add to treasury (this is done in the startGame function)
      amount_to_withdraw  = (amount_to_withdraw
              * (100 - games[gameId].current_house_cut)) / 100;

      //Check that the game has at least amount_to_withdraw in the game:
      if(games[gameId].totalInGame < amount_to_withdraw){
        return false;
      }

      delete games[gameId].backers[msg.sender];
      games[gameId].totalInGame =
          sub(games[gameId].totalInGame, amount_to_withdraw);
      msg.sender.transfer(amount_to_withdraw);
      PaidOut(amount_to_withdraw, gameId, msg.sender);

    } else if (games[gameId].winner == SIDE_B){
      //If msg.sender did not contribute to side A, or has already withdrawn
      if(games[gameId].backers[msg.sender].amtB == 0){
        return false;
      }

      //If no one submitted a bet to the other side, issue a refund
      if(games[gameId].totalInB == 0
        && games[gameId].backers[msg.sender].amtA != 0){

        amount_to_withdraw = games[gameId].backers[msg.sender].amtA;
        games[gameId].totalInGame =
            sub(games[gameId].totalInGame, amount_to_withdraw);
        delete games[gameId].backers[msg.sender];
        msg.sender.transfer(amount_to_withdraw);
        return true;
      }

      amount_to_withdraw =
          add(amount_to_withdraw, games[gameId].backers[msg.sender].amtB);

      amount_to_withdraw += ((games[gameId].backers[msg.sender].amtB
              * games[gameId].totalInA) / games[gameId].totalInB);

      amount_to_withdraw = (amount_to_withdraw
              * (100 - games[gameId].current_house_cut)) / 100;

      //Check that the game has at least amount_to_withdraw in the game:
      if(games[gameId].totalInGame < amount_to_withdraw){
        return false;
      }

      delete games[gameId].backers[msg.sender];
      games[gameId].totalInGame =
          sub(games[gameId].totalInGame, amount_to_withdraw);
      msg.sender.transfer(amount_to_withdraw);
      PaidOut(amount_to_withdraw, gameId, msg.sender);
    } else { //game ended in a tie
      if(games[gameId].backers[msg.sender].amtA == 0
        && games[gameId].backers[msg.sender].amtB == 0){
        return false;
      }

      amount_to_withdraw =
          add(amount_to_withdraw, games[gameId].backers[msg.sender].amtA);
      amount_to_withdraw =
          add(amount_to_withdraw, games[gameId].backers[msg.sender].amtB);

      amount_to_withdraw = (amount_to_withdraw
              * (100 - games[gameId].current_house_cut_tie)) / 100;

      if(games[gameId].totalInGame < amount_to_withdraw){
        return false;
      }

      delete games[gameId].backers[msg.sender];
      games[gameId].totalInGame =
          sub(games[gameId].totalInGame, amount_to_withdraw);
      msg.sender.transfer(amount_to_withdraw);
      PaidOut(amount_to_withdraw, gameId, msg.sender);
    }
    return true;
  }

  /*
  * GET methods
  */
  function isGameRunning(uint gameId) constant returns(bool){
    return now <= games[gameId].endTime;
  }

  function getTotalInGame(uint gameId) constant returns(uint){
    return add(games[gameId].totalInA, games[gameId].totalInB);
  }

  function getTotalInA(uint gameId) constant returns(uint){
    return games[gameId].totalInA;
  }

  function getTotalInB(uint gameId) constant returns(uint){
    return games[gameId].totalInB;
  }

  function getMyAmtInA(uint gameId) constant returns(uint){
    return games[gameId].backers[msg.sender].amtA;
  }

  function getMyAmtInB(uint gameId) constant returns(uint){
    return games[gameId].backers[msg.sender].amtB;
  }

  function getCurGameId() constant returns(uint){
    return curGameId;
  }

  function getGameHouseCut(uint gameId) constant returns(uint){
    return games[gameId].current_house_cut;
  }

  function getGameHouseCutTie(uint gameId) constant returns(uint){
    return games[gameId].current_house_cut_tie;
  }

  function getGameBounty(uint gameId) constant returns(uint){
    return games[gameId].current_bounty;
  }

  function getGameWinner(uint gameId) constant returns(string){
    if(games[gameId].winner == SIDE_A){
      return 'A';
    } else if(games[gameId].winner == SIDE_B){
      return 'B';
    } else if(games[gameId].winner == TIE){
      return 'T';
    } else {
      return 'P'; //In progress
    }
  }

  function getCurSideA() constant returns(uint){
    return games[curGameId].totalInA;
  }

  function getCurSideB() constant returns(uint){
    return games[curGameId].totalInB;
  }
}
