# SpoofOfStake
Ethereum DApp loosely based on Ethereum's future PoS mechanic

### Game Concept
Proof of Stake - Verification method in which those who report are rewarded for honest reporting and punished for dishonest reporting.

Spoof of Stake emulates this verification method by asking players to report on which of two pools will hold the least value at the end of the game.
By using the stake verification method, Spoof of Stake mimics  markets in the way it uses market sentiment to predict relative value. In theory, the value of the two pools should always trend around a 50/50 split.

### Strategy / Game Theory:
##### The Equal Split Method
As the reward for reporting accurately must always be over 100% of the value staked, it follows that a dominant strategy would be to report equally in both pools, yielding an EV of 1 at an absolute minimum at an equal 50/50 split. 
To counter this, a 5% fee on the game has been introduced making the equal split method a losing strategy at value discrepancies between the pools under 2.44% (1/48.78*51.22=1.005002). The fee will be adjusted as necessary if we feel the equal split method has become too worthless or too dominant. What this should mean is that as liquidity increases, the necessity of a fee will be diminished as games trend closer and closer towards a 50/50 split
##### The Greater Good Sacrifice
A player may find themselves in a position in which they have 4 ether in pool A which currently holds .3 more ether than pool B. By sacrificing >.3 ether into Pool B, the player both hedges against their initial position, and increases the odds that their larger report is correct.
This method is totally encouraged. As are all methods of manipulation. S.o.S requires a player to accurately report which side will have the least value, correctly predicting the sum actions of all including our example player.
### Equity Token
##### Controlling Interest
Token holders control the contract via a mechanism that allows for voting on the operator of the contract who may start and stop the game and change the fee percent.

##### Profits
###### Profit Pool
All profits will be accumulated into a pool that can be accessed by the token holders
###### Token Burning
By burning one’s tokens, one relinquishes their equity in exchange for their share of the profit pool. This reduces transaction costs of periodic dividends, eliminates lock up periods that periodic dividends require, and protects token holders against low liquidity on exchanges.
    
### Security
##### No Oracles
###### Trustless
Without the need for random number generation, we do not have to use an Oracle. While Oracles can be verified after the fact, players can be confident while playing our game that they are protected.
###### Cost saving
Oracles have costs, no oracle, no cost.

##### No bankroll
Because the game is played between players, there is no need for a bankroll that could be lost through play or stolen by mismanagement.
The profit pool appears similar to a bankroll in that it is a central pool of ether, but it is not by design at risk and is secured by our smart contract
##### Contract Audit
The S.o.S contract has been audited by a third party and will continue to be audited on a regular basis.
In the event of a discovery of a bug in the contract, the game will be stopped until such time that it can be confidently stated to be fixed, at which such time the game will continue regular operation. 
In the event of a catastrophic or unfixable bug, play on current contract will be stopped permanently and a grace period will be put in place for all token holders to withdraw from exchanges, after which a new contract will be created and a new token issuance will occur, air dropped to all token holders according to their stake. 

### Technical details
##### Backing
Choosing and backing a side is done via the “back” function, which takes an unsigned integer as an argument, representing the side choice. Side A is chosen by submitting 1, and Side B is chosen by submitting 2. 
This function is locked when there is no current active game or when the contract is paused.
As a security measure, choices made within a certain amount of time of the end of the game (denoted by the updateable variable “bufferTime”) will extend the end of the game by an amount of time (denoted by the updateable variable “timeAdd”). The default bufferTime is 1 minute, while the default time to add is 5 minutes. This is to ensure that no miners can place the final backing, which could be abusable.
##### Winnings withdrawal
Winnings withdrawal is done via the “withdrawWinnings” function, which takes an unsigned integer as an argument, representing the game id to withdraw from.
This function is locked when the game associated with the given id is still in progress, when the contract is paused, when the given id is invalid or does not represent a game that has been played, or when there is no active game. The latter is to ensure that the startGame function has been called before withdrawals are made, ensuring the game winner variable has been updated properly.
If the game associated with the given id only had ETH on one side, a refund is issued to anyone withdrawing from that game: no house cut is taken, and the winning and losing side are ignored. This is to protect users from a low-activity game.
If the game associated with the given id ended in a tie, the house cut taken from each withdrawal is determined by the “house_cut_tie” variable. Otherwise, the house cut is determined by the “house_cut” variable.
##### Starting a New Game
Starting a new game is done via the “startGame” function. This can only be done if there is no active game, or if the contract is not paused. Beyond creating a new active game, this function also declares the winner of the previous game, takes the house cut, awards a bounty, and allows withdrawals on the previous game to take place.
To incentivise players to start a new game once the current game has been completed, players are awarded a bounty for calling this function, equal to a percentage of the house cut taken from the game. This percentage is stored in the updateable variable “startgame_bounty_percent.”
If the previous game had no ETH in it, the game’s time is simply extended. This is the first thing checked in the function, and is a gas-saving measure. In this event, there is no bounty for the function caller. 
If one side had no ETH in it, but the other did, a new game is started without taking a house cut, so that the players from the previous game get their refund. In this event, there is no bounty.
Otherwise, a house cut is taken out of the total in the game, and a bounty is taken from the house cut. Both are awarded to the treasury and the function caller respective, and a new game is started. 

