pragma solidity ^0.4.15;

import "https://github.com/wadeAlexC/SpoofOfStake/blob/master/contracts/SpoofOfStake.sol";

contract SpoofOfStake{
  function pause() {}
  function unpause() {}
  function setHouseCut(uint house_cut) {}
  function setHouseCutTie(uint house_cut_tie) {}
  function setBountyPercent(uint bounty_percent) {}
  function withdrawTreasury() {}
  function setBufferTime(uint time) {}
  function setTimeAdd(uint time) {}
}

//Implements all ERC20 methods
contract SOSToken{

  //Name and ticker information
  string public constant name = "SOSToken";
  string public constant symbol = "SOS";
  uint8 public constant decimals = 2;

  //Keeps track of where token holders currently have their votes allocated
  struct Vote{
    address to;
    uint votes;
  }

  //Amounts each user holds
  mapping(address => uint) balances;

  //Amounts approved for spending by the owner account
  mapping(address => mapping(address => uint)) allowed;

  //Keeps track of how many votes each address receives for "privileged" status
  mapping(address => uint) votes;

  //Maps a voter to the address they have already voted on, as well as how many votes they have sent
  mapping(address => Vote) current_votes;

  //Address of the privileged account that can interact with the SpoofOfStake contract
  address public privileged;

  //SpoofOfStake instance along with the address
  SpoofOfStake SOSContract; /*TODO*/
  address public SOSAddr;

  uint totalSupply = 1000;

  event Transfer(address indexed _from, address indexed _to, uint _value);

  event Approval(address indexed _owner, address indexed _spender, uint _value);

  //Constructor
  function SOSToken(){
    privileged = msg.sender;
    balances[msg.sender] = totalSupply;
    SOSContract = new SpoofOfStake(SOSAddr);

  }

  modifier onlyPrivileged(){
    require(msg.sender == privileged);
    _;
  }

  //Returns the balance of the address passed in
  function balanceOf(address _address) constant returns(uint){
    return balances[_address];
  }

  //Returns the amount allocated to the spender by the owner's account
  function allowance(address _owner, address _spender) constant returns(uint){
    return allowed[_owner][_spender];
  }

  //Transfers tokens from the owner's account to the address provided
  function transfer(address _to, uint _amount) returns(bool success){
    require(balances[msg.sender] >= _amount);
    require(_amount > 0);
    require(balances[_to] + _amount > balances[_to]);
    balances[msg.sender] -= _amount;
    balances[_to] += _amount;
    Transfer(msg.sender, _to, _amount);
    return true;
  }

  //Use allowed/allocated funds to transfer from on account to another
  function transferFrom(address _from, address _to, uint _amount) returns (bool success){
    require(balances[_from] >= _amount);
    require(_amount > 0);
    require(balances[_to] + _amount > balances[_to]);
    require(allowed[_from][msg.sender] >= _amount);
    balances[_from] -= _amount;
    allowed[_from][msg.sender] -= _amount;
    balances[_to] += _amount;
    Transfer(_from, _to, _amount);
    return true;
  }

  function approve(address _spender, uint _amount) returns(bool success){
    allowed[msg.sender][_spender] = _amount;
    Approval(msg.sender, _spender, _amount);
    return true;
  }

  //Allocates your portion of the vote to the given address
  function votePrivilegedAddr(address _choice) returns(bool success){
    require(balances[msg.sender] > 0);
    uint to_allocate = balances[msg.sender];

    //Remove any previous votes the sender has created
    uint to_remove = current_votes[msg.sender].votes;
    if(to_remove != 0){
      address remove_from = current_votes[msg.sender].to;
      votes[remove_from] -= to_remove;
    }

    //Add the new votes to the submitted choice
    votes[_choice] += to_allocate;
    current_votes[msg.sender] = Vote({
        to: _choice,
        votes: to_allocate
    })

    //Update privileged address, if necessary
    if(votes[_privileged] <= votes[_choice]){
      _privileged = _choice;
    }

    return true;

  }

  //Burns the number of tokens specified and sends that proportion of the totalSupply from the treasury
  function claim(uint tokens) returns(bool success){
    require(balances[msg.sender] >= tokens);
    require(totalSupply >= tokens);
    uint to_transfer = this.balance * tokens / totalSupply;
    balances[msg.sender] -= tokens;
    totalSupply -= tokens;
    msg.sender.transfer(to_transfer);
    return true;
  }

  /*
  * Privileged functions:
  */
  function pauseGame() onlyPrivileged returns(bool success){
    SOSContract.pause();
    return true;
  }

  function unpauseGame() onlyPrivileged returns(bool success){
    SOSContract.unpause();
    return true;
  }

  function setHouseCut(uint house_cut) returns(bool success){
    SOSContract.setHouseCut(house_cut);
    return true;
  }

  function setHouseCutTie(uint house_cut_tie) returns(bool success){
    SOSContract.setHouseCutTie(house_cut_tie);
    return true;
  }

  function withdrawTreasury() returns(bool success){
    SOSContract.withdrawTreasury();
    return true;
  }

  function setBufferTime(uint time) returns(bool success){
    SOSContract.setBufferTime(time);
    return true;
  }

  function setTimeAdd(uint time) returns(bool success){
    SOSContract.setTimeAdd(time);
    return true;
  }

  function setBountyPercent(uint percent) returns(bool success){
    SOSContact.setBountyPercent(percent);
    return true;
  }


}
