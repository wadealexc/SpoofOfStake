pragma solidity ^0.4.11;

contract SpoofOfStake2{

  //stringUtils string comparison
  //full library:
  //github.com/ethereum/dapp-bin/blob/master/library/stringUtils.sol
  function compare(string _a, string _b) internal returns(int){
    bytes memory a = bytes(_a);
    bytes memory b = bytes(_b);
    uint minLength = a.length;
    if(b.length < minLength) minLength = b.length;
    for(uint i = 0; i < minLength; i++){
      if(a[i] < b[i]){
        return -1;
      } else if (a[i] > b[i]){
        return 1;
      }
    }
    if(a.length < b.length){
      return -1;
    }else if (a.length > b.length){
      return 1;
    }else{
      return 0;
    }
  }

  function equal(string _a, string _b) internal returns(bool){
    return compare(_a, _b) == 0;
  }

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
  Game curGame;
  //Mapping of all gameIds to their respective games
  mapping(uint => Game) games;
  //owner
  address public owner;
  //Amount of Ether taken from house edge and not withdrawn from the contract
  uint public treasury;

  uint public house_cut_percent;

  //Percent of the house_cut received by anyone who calls startNewGame when
  //there is no current running game
  uint public startgame_bounty_percent;
  mapping(address => uint) bounty_allowances;


  //Constructor
  function SpoofOfStake2(){
    owner = msg.sender;
    curGame = Game({
      gameId:0,
      startTime:now,
      endTime:now + 1 hours,
      totalInA:0,
      totalInB:0,
      totalInGame:0,
      winner:gameWinner.InProgress,
      locked:false
    });
    games[curGame.gameId] = curGame;
    house_cut_percent = 4;
    startgame_bounty_percent = 1;
  }

  //Throws if the curGame has already ended
  modifier gameRunning(){
    if(now > curGame.endTime){ //if the curGame has ended, throw
      throw;
    }
    _;
  }

  //Throws if the gameId provided pertains to a game in session
  modifier validId(uint gameId){
    if(now <= games[gameId].endTime){
      throw;
    }
    _;
  }

  modifier notLocked(uint gameId){
    if(games[gameId].locked == true){
      throw;
    }
    _;
  }

  /*
  * Events:
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
  function back(string choice) gameRunning payable returns(bool success){
    if(equal(choice, "A")){ //User backs side A
      curGame.totalInA += msg.value;
      curGame.totalInGame += msg.value;
      curGame.backers[msg.sender].amtA += msg.value;
      LogBack(msg.sender, "A", msg.value);
      return true;
    } else if (equal(choice, "B")){ //User backs side B
      curGame.totalInB += msg.value;
      curGame.totalInGame += msg.value;
      curGame.backers[msg.sender].amtB += msg.value;
      LogBack(msg.sender, "B", msg.value);
    } else { //No choice, or an invalid choice was made
      return false;
    }
  }

  //TODO: create bounty
  //Create a new game if there is no game running
  function startNewGame() returns(bool success){
    //Split up for readability:
    uint gameStartA = 0;
    uint gameStartB = 0;

    //Decide winner
    if(now > curGame.endTime){
      if(curGame.totalInA > curGame.totalInB){ //A won
        curGame.winner = gameWinner.SideA;
      } else if (curGame.totalInB > curGame.totalInA){ //B won
        curGame.winner = gameWinner.SideB;
      } else { //tie
        curGame.winner = gameWinner.Tie;
      }
    } else {
      return false;
    }

    //Check for old games to lock:
    if(curGame.gameId - 7 >= 0){
      uint amtToDistribute = games[curGame.gameId - 7].totalInGame;
      games[curGame.gameId - 7].totalInGame = 0;
      //Lock the old game
      games[curGame.gameId - 7].locked = true;
      //If the current game was a tie, distribute Ether equally
      if(curGame.winner == gameWinner.Tie){
        gameStartA += amtToDistribute / 2;
        gameStartB += amtToDistribute / 2;
      } else { //Otherwise, place all of the Ether on side A
        gameStartA += amtToDistribute;
      }
    }

    //If the current game was a tie, lock withdrawals and roll Ether over
    //to the next game
    if(curGame.winner == gameWinner.Tie){
      //lock withdrawals
      curGame.locked = true;
      gameStartA += curGame.totalInA;
      gameStartB += curGame.totalInB;
      //set total in game to 0, as the Ether rolls over
      curGame.totalInGame = 0;
    }

    /*
    *Take house cut of the previous game. No cut is taken in event of a tie.
    *This is not explicitly checked for, but totalInGame is set to 0 in event
    *of a tie, so house_cut will also be 0
    */
    uint house_cut = curGame.totalInGame * (house_cut_percent / 100);
    //totalInGame, totalInA, and totalInB decreased so withdrawals are correct
    curGame.totalInGame = curGame.totalInGame *
        ((100 - house_cut_percent) / 100);
    //It doesn't matter that these change in the event of a tie as withdrawals
    //are locked anyway
    curGame.totalInA = curGame.totalInA *
        ((100 - house_cut_percent) / 100);
    curGame.totalInB = curGame.totalInB *
        ((100 - house_cut_percent) / 100);

    bounty_allowances[msg.sender] += house_cut *
        (startgame_bounty_percent / 100);
    house_cut = house_cut - (house_cut * (startgame_bounty_percent / 100));
    treasury += house_cut;
    HouseCut(house_cut, house_cut_percent, treasury);

    //Start a new game with the calculated start amounts
    curGame = Game({
      gameId: curGame.gameId + 1,
      startTime: now,
      endTime: now + 1 hours,
      totalInA: gameStartA,
      totalInB: gameStartB,
      totalInGame: gameStartA + gameStartB,
      winner: gameWinner.InProgress,
      locked: false
    });
    games[curGame.gameId] = curGame;
    NewGame(curGame.startTime, curGame.endTime, curGame.totalInGame);
    return true;
  }

  /*
  *Once a game is complete, winnings can be withdrawn. This will fail if
  *the game is more than 7 games old, or if the game is still running
  */
  function withdrawWinnings(uint gameId) validId(gameId) notLocked(gameId)
      returns (bool success){
    //if side A won
    Game game = games[gameId];
    uint amount_to_withdraw = 0;
    BackingAmt backing = game.backers[msg.sender];

    if(game.winner == gameWinner.SideA){
      //If msg.sender did not contribute to side A, or has already withdrawn
      if(backing.amtA == 0){
        return false;
      }

      amount_to_withdraw += backing.amtA;
      //TODO check math here - floats/doubles not yet possible in solidity
      uint winning_ratio_A = backing.amtA / game.totalInA;
      amount_to_withdraw += (winning_ratio_A * game.totalInB);

      //Check that the game has at least amount_to_withdraw in the game:
      if(game.totalInGame < amount_to_withdraw){
        return false;
      }

      //Otherwise, send winnings
      if(msg.sender.send(amount_to_withdraw) == true){
        //transfer successful:
        game.totalInGame -= amount_to_withdraw;
        backing.amtA = 0;
        backing.amtB = 0;
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
      uint winning_ratio_B = backing.amtB / game.totalInB;
      amount_to_withdraw += (winning_ratio_B * game.totalInA);

      //Check that the game has at least amount_to_withdraw in the game:
      if(game.totalInGame < amount_to_withdraw){
        return false;
      }

      //Otherwise, send winnings
      if(msg.sender.send(amount_to_withdraw) == true){
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

  /*
  * GET methods
  */
  function isGameRunning() constant returns(bool){
    return now < curGame.endTime;
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
  //
}
