pragma solidity ^0.4.15;

import "./SpoofOfStake.sol";

//Implements all ERC20 methods
contract SOSToken{

  //Name and ticker information
  string public constant name = "SOSToken";
  string public constant symbol = "SOS";
  uint8 public constant decimals = 2;

  //Amounts each user holds
  mapping(address => uint) balances;

  //Amounts approved for spending by the owner account
  mapping(address => mapping(address => uint)) allowed;

  //Keeps track of how many votes each address receives for "privileged" status
  mapping(address => uint) votes;

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
    SOSContract = SpoofOfStake(SOSAddr);

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
  function votePrivilegedAddr(address _privileged) returns(bool success){
    votes[_privileged] = balances[msg.sender];
    //If there are enough votes for a particular address, they are now the privileged address
    //Enough votes is "greater than 50%"
    if(votes[_privileged] > totalSupply / 2){
      privileged = _privileged;
      SOSContract.newPrivileged(privileged);
      return true;
    }
    return true;
  }

  /*
  * Privilaged functions:
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


}
