pragma solidity ^0.4.13;

contract SpoofOfStake2{

  //Allows a mapping between a user and 2 backing amounts
  struct BackingAmt{
    uint amtA;
    uint amtB;
  }

  enum gameWinner{
    SideA,
    SideB,
    Tie,
    InProgress
  }

  //
  struct Game{
    //For access and Ether withdrawal from previous games
    uint gameId;
    //Keeps track of every backer for this game
    mapping(address => BackingAmt) backers;
    //Start and end times of the game
    uint startTime;
    uint endTime;
    //Keeps track of the overall amounts sent to A and B
    //Remains constant after a game is finished
    uint totalInA;
    uint totalInB;
    //Keeps track of the total Ether the game holds. Changes based on
    //withdrawals after a game
    uint totalInGame;
    gameWinner winner;
    //Ether is no longer withdrawable once a game is 7 days old
    bool locked;
  }

  //Contract variables:
  //The current running game
  uint curGameId;
  //Mapping of all gameIds to their respective games
  mapping(uint => Game) games;
  //owner
  address public owner;
  //Amount of Ether taken from house edge and not withdrawn from the contract
  uint public treasury;

  bool public paused;

  uint public gameDur;

  uint public house_cut_percent;
  uint public house_cut_percent_tie;

  //TEMP
  bool public flagA;
  bool public flagB;
  bool public flagC;
  uint public valFlagA;
  uint public valFlagB;
  uint public valFlagC;

  //Percent of the house_cut received by anyone who calls startNewGame when
  //there is no current running game
  uint public startgame_bounty_percent;
  mapping(address => uint) bounty_allowances;


  //Constructor
  function SpoofOfStake2(){
    owner = msg.sender;
    paused = false;
    gameDur = 1 minutes; /*TODO*/
    games[0] = Game({
      gameId:0,
      startTime:now,
      endTime: now + gameDur,
      totalInA:0,
      totalInB:0,
      totalInGame:0,
      winner:gameWinner.InProgress,
      locked:false
    });
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

  modifier notLocked(uint gameId){
    require(games[gameId].locked != true);
    _;
  }

  modifier curGameExists(){
    require(games[curGameId].startTime < now
      && games[curGameId].endTime > now);

    _;
  }

  modifier validSideChoice(string choice){
    if(equal(choice, 'A')){
      flagA = true;
    } else if (equal(choice, 'B')){
      flagB = true;
    } else {
      flagC = true;
    }
    require(equal('A', choice) || equal('B', choice));
    _;
  }

  modifier notPaused(){
    require(paused == false);
    _;
  }

  modifier onlyOwner(){
    require(msg.sender == owner);
    _;
  }

  /*
  * EVENTS:
  */

  //Event displays a user backing a side
  event LogBack(address indexed sender, string indexed choice, uint value);

  //Event displays amounts added to the treasury
  event HouseCut(uint indexed cut_amount, uint indexed cut_percent, uint indexed treasury_amt);

  //Event displays the start of a new game
  event NewGame(uint indexed startTime, uint indexed endTime, uint indexed totalInGame);

  //Event displays a payment to a winner
  event PaidOut(uint indexed amt_paid, uint indexed gameId, address _to);

  //Allows a player to back a side - A or B by calling this function
  //And passing in a string indicating the choice.
  //Accepted strings: "A" or "B". Anything else will return false
  function back(string choice)
    activeGameExists
    validSideChoice(choice)
    notPaused
    payable
    returns(bool success)
    {
    if(equal(choice, "A")){ //User backs side A
      games[curGameId].totalInA += msg.value;
      games[curGameId].totalInGame += msg.value;
      games[curGameId].backers[msg.sender].amtA += msg.value;
      //LogBack(msg.sender, "A", msg.value);
      return true;
    } else if (equal(choice, "B")){ //User backs side B
      games[curGameId].totalInB += msg.value;
      games[curGameId].totalInGame += msg.value;
      games[curGameId].backers[msg.sender].amtB += msg.value;
      //LogBack(msg.sender, "B", msg.value);
      return true;
    } else { //No choice, or an invalid choice was made
      //This should never be accessed, because of the validSideChoice modifier
      return false;
    }
  }

  //Create a new game if there is no game running
  //The person who calls this function will receive a bounty equal to a portion
  //of the house cut from this game as a reward
  /*TODO move deposit mappings to the new game in case of a tie*/
  function startGame()
    noActiveGameExists
    notPaused
    returns(bool success)
    {

    //To save on gas, if the previous game had no ether in it, we simply
    //extend the endTime and return. Unfortunately in this case there is no
    //bounty for the sender but the gas cost is also low
    if(games[curGameId].totalInGame == 0){
      games[curGameId].endTime += gameDur;
      return true;
    }

    //decide the winner
    if(games[curGameId].totalInA < games[curGameId].totalInB){
        games[curGameId].winner = gameWinner.SideA;
    } else if (games[curGameId].totalInB < games[curGameId].totalInA){
      games[curGameId].winner = gameWinner.SideB;
    } else {
      flagA = true;
      games[curGameId].winner = gameWinner.Tie;
    }
    flagB = true;

    uint newSideA = 0;
    uint newSideB = 0;
    uint house_cut = 0;
    uint bounty = 0;
    //If the game is a tie we want to take the house *tie* cut and roll
    //the rest of the funds over
    if(games[curGameId].winner == gameWinner.Tie){
      house_cut += (games[curGameId].totalInGame * house_cut_percent_tie) / 100;
      games[curGameId].totalInGame -= house_cut;
      newSideA += games[curGameId].totalInGame / 2;
      newSideB += newSideA;
      games[curGameId].locked = true;
    } else {
      house_cut += (games[curGameId].totalInGame * house_cut_percent) / 100;
      games[curGameId].totalInGame -= house_cut;
    }

    bounty += (house_cut * startgame_bounty_percent) / 100;
    house_cut -= bounty;
    treasury += house_cut;

    //If there is an old game we want to lock, take any remaining funds from it
    //and add them to the lastest game.
    //If the last game was a tie, split the old funds evenly between the two sides
    //If the last game was not a tie, place all of the old funds on A
    if(curGameId - 25 >= 0){
      games[curGameId - 25].locked = true;
      uint old_funds = games[curGameId - 25].totalInGame;
      games[curGameId - 25].totalInGame = 0;
      if(games[curGameId].winner == gameWinner.Tie){
        //In the
        newSideA += old_funds / 2;
        newSideB = newSideA;
      } else {
        newSideA += old_funds;
      }
    }

    //Now increment curGameId and create a new game with the start amounts:
    curGameId += 1;
    games[curGameId] = Game({
      startTime: now,
      endTime: now + 1 minutes,
      gameId: curGameId,
      totalInA: newSideA,
      totalInB: newSideB,
      totalInGame: newSideA + newSideB,
      winner: gameWinner.InProgress,
      locked: false
    });

    //Attempt to send the person who called this function the bounty
    msg.sender.transfer(bounty);

    return true;

  }

  /*
  *Once a game is complete, winnings can be withdrawn. This will fail if
  *the game is more than 7 games old, or if the game is still running
  *This will also fail if there is not a current game running, to prevent
  *withdrawals from the previous game if the startGame function has not been called
  */
  function withdrawWinnings(uint gameId) notRunning(gameId) notLocked(gameId)
      curGameExists() returns (bool success){
    //if side A won
    Game storage game = games[gameId];
    uint amount_to_withdraw = 0;
    BackingAmt storage backing = game.backers[msg.sender];
    if(game.winner == gameWinner.SideA){
      //If msg.sender did not contribute to side A, or has already withdrawn
      if(backing.amtA == 0){
        return false;
      }

      amount_to_withdraw += backing.amtA;
      /*TODO check math here*/
      amount_to_withdraw += ((backing.amtA * game.totalInB) / game.totalInA);
      //Takes out the house cut, but does not add to treasury (this is done in the startGame function)
      amount_to_withdraw  = (amount_to_withdraw * (100 - house_cut_percent)) / 100;

      //Check that the game has at least amount_to_withdraw in the game:
      if(game.totalInGame < amount_to_withdraw){
        return false;
      }

      //Otherwise, send winnings
      if(msg.sender.send(amount_to_withdraw) == true){
        //transfer successful:
        game.totalInGame -= amount_to_withdraw;
        valFlagA = amount_to_withdraw;
        game.backers[msg.sender].amtA = 0; //works correctly
        game.backers[msg.sender].amtB = 0;
        PaidOut(amount_to_withdraw, gameId, msg.sender);
        return true;
      } else {
        return false;
      }
    } else if (game.winner == gameWinner.SideB){
      //If msg.sender did not contribute to side A, or has already withdrawn
      if(backing.amtB == 0){
        return false;
      }

      amount_to_withdraw += backing.amtB;
      //TODO check math here - floats/doubles not yet possible in solidity
      amount_to_withdraw += ((backing.amtB * game.totalInA) / game.totalInB);

      amount_to_withdraw = (amount_to_withdraw * (100 - house_cut_percent)) / 100;
      //Check that the game has at least amount_to_withdraw in the game:
      if(game.totalInGame < amount_to_withdraw){
        return false;
      }
      //Otherwise, send winnings
      if(msg.sender.send(amount_to_withdraw) == true){
        valFlagA = amount_to_withdraw;
        //transfer successful:
        game.totalInGame -= amount_to_withdraw;
        backing.amtA = 0;
        backing.amtB = 0;
        PaidOut(amount_to_withdraw, gameId, msg.sender);
        return true;
      } else {
        return false;
      }
    } else { //A tie - this should never trigger, as a tied game is locked
      return false;
    }
  }

  //Determines if two strings are the same
  function equal(string _a, string _b) internal returns(bool){
    return sha3(_a) == sha3(_b);
  }

  /*
  * GET methods
  */
  function isGameRunning(uint gameId) returns(bool){
    return now <= games[gameId].endTime;
  }

  function getNow() constant returns(uint){
    return now;
  }

  function getGameEndTime(uint gameId) constant returns(uint){
    return games[gameId].endTime;
  }

  function getTimeTillGameEnd(uint gameId) constant returns(int){
    return int(now) - int(games[gameId].endTime);
  }

  //returns the total amount of ether in a game corresponding to a gameId
  function getTotalInGame(uint gameId) constant returns(uint){
    return games[gameId].totalInGame;
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
  //TODO: temp getters
  function getOwner() constant returns(address){
    return owner;
  }

  function getBalance() constant returns(uint){
    return this.balance;
  }

  function getTreasury() constant returns(uint){
    return treasury;
  }

  function getFlagA() constant returns(bool){
    return flagA;
  }

  function getFlagB() constant returns(bool){
    return flagB;
  }

  function getFlagC() constant returns(bool){
    return flagC;
  }

  function getValFlagA() constant returns(uint){
    return valFlagA;
  }

  function getValFlagB() constant returns(uint){
    return valFlagB;
  }

  function getValFlagC() constant returns(uint){
    return valFlagC;
  }

  /*function getBackAmtA(uint gameId) constant returns(uint){
    return games[gameId].backers[msg.sender].amtA;
  }

  function getBackAmtB(uint gameId) constant returns(uint){
    return games[gameId].backers[msg.sender].amtB;
  }*/

  function getCurGameId() constant returns(uint){
    return curGameId;
  }

  function getGameWinner(uint gameId) constant returns(string){
    if(games[gameId].winner == gameWinner.SideA){
      return 'A';
    } else if(games[gameId].winner == gameWinner.SideB){
      return 'B';
    } else if(games[gameId].winner == gameWinner.Tie){
      return 'T';
    } else {
      return 'P';
    }
  }
  //
}
