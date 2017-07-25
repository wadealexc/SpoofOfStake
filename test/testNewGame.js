var SpoofOfStake2 = artifacts.require('./SpoofOfStake2.sol');
var TestRPC = require("ethereumjs-testrpc");

var val = web3.toWei(1, 'ether');
console.log(val)

contract('SpoofOfStake2', function(accounts){
  var SoS2 = SpoofOfStake2.deployed();
  var account_arr = accounts;
  //console.log(web3.eth.getBalance(account_arr[0]).valueOf());

  it('should correctly start a new game when the time is up', function(accounts){
    SoS2.then(function(instance){
      return instance.back('A', {'from': account_arr[1], 'value': web3.toWei(0.5, 'ether')});
    }).then(function(tx){
      printSides(SoS2, 0);
      printMyAmts(SoS2, account_arr[1], 1);
      SoS2.then(function(instance){
        return instance.back('A', {'from': account_arr[2], 'value': web3.toWei(0.3, 'ether')});
      }).then(function(tx){
        printSides(SoS2, 0);
        printMyAmts(SoS2, account_arr[2], 2);
        SoS2.then(function(instance){
          return instance.back('B', {'from': account_arr[3], 'value': web3.toWei(0.7, 'ether')});
        }).then(function(tx){
          printSides(SoS2, 0);
          printMyAmts(SoS2, account_arr[3], 3);
          SoS2.then(function(instance){
            return instance.back('B', {'from': account_arr[4], 'value': web3.toWei(0.05, 'ether')});
          }).then(function(tx){
            printSides(SoS2, 0);
            printMyAmts(SoS2, account_arr[4], 4);
            console.log(1);
            /*
            *now try to start a new game
            */
            SoS2.then(function(instance){
              console.log(2);
              return instance.isGameRunning.call(0);
            }).then(function(running){
              console.log("GAME RUNNING: " + running);
              console.log("WAITING.....");
            })
            setTimeout(function(){
              SoS2.then(function(instance){
                return instance.getGameWinner.call(0);
              }).then(function(winner){
                console.log("WINNER: " + winner)
              });
              printBal(account_arr[1], 1);
              printBal(account_arr[2], 2);
              printBal(account_arr[3], 3);
              printBal(account_arr[4], 4);
              SoS2.then(function(instance){
                return instance.startGame({'from': account_arr[4]})
              }).then(function(tx){
                console.log("New game started")
                SoS2.then(function(instance){
                  return instance.getCurGameId.call()
                }).then(function(id){
                  console.log("GAME ID: " + id);
                })
                SoS2.then(function(instance){
                  return instance.getGameWinner.call(0);
                }).then(function(winner){
                  console.log("WINNER: " + winner)
                  assert.equal(winner, 'A', 'winner not correct')
                });
                printBal(account_arr[1], 1);
                printBal(account_arr[2], 2);
                printBal(account_arr[3], 3);
                printBal(account_arr[4], 4);
                //See the treasury bal:
                SoS2.then(function(instance){
                  return instance.getTreasury.call()
                }).then(function(val){
                  console.log("Treasury contains: " + web3.fromWei(val, 'ether'))
                });
                //See how much the bounty was:
                printValFlagsEth(SoS2);
                //See if the bounty sent:
                printBoolFlags(SoS2);
                /*
                * Now try some withdrawals
                */
                SoS2.then(function(instance){
                  return instance.withdrawWinnings(0, {'from': account_arr[1]});
                }).then(function(tx){
                  printBoolFlags(SoS2);
                  printValFlagsEth(SoS2);
                  printBal(account_arr[1], 1);
                })
              })
            }, 80000)
          })
        })
      })
    })
  })
});

function printBal(account, index){
  console.log("ACC " + index + ": " + web3.fromWei(web3.eth.getBalance(account).valueOf(), 'ether'));
}

function printSides(contract, index){
  contract.then(function(instance){
    return instance.getTotalInA.call(index);
  }).then(function(tot){
    console.log("SIDE A TOT: " + tot);
  });
  contract.then(function(instance){
    return instance.getTotalInB.call(index);
  }).then(function(tot){
    console.log("SIDE B TOT: " + tot);
  });
}

function printMyAmts(contract, account, index){
  contract.then(function(instance){
    return instance.getMyAmtInA.call(0, {'from': account});
  }).then(function(tot){
    console.log(index + " A TOT: " + tot.valueOf());
  });
  contract.then(function(instance){
    return instance.getMyAmtInB.call(0, {'from': account});
  }).then(function(tot){
    console.log(index + " B TOT: " + tot.valueOf());
  });
}

function printBoolFlags(contract){
  contract.then(function(instance){
    return instance.flagA.call();
  }).then(function(flag){
    console.log("FLAG A: " + flag);
  });

  contract.then(function(instance){
    return instance.flagB.call();
  }).then(function(flag){
    console.log("FLAG B: " + flag);
  });

  contract.then(function(instance){
    return instance.flagC.call();
  }).then(function(flag){
    console.log("FLAG C: " + flag);
  });
}

function printValFlags(contract){
  contract.then(function(instance){
    return instance.valFlagA.call();
  }).then(function(flag){
    console.log("VAL FLAG A: " + flag);
  });

  contract.then(function(instance){
    return instance.valFlagB.call();
  }).then(function(flag){
    console.log("VAL FLAG B: " + flag);
  });

  contract.then(function(instance){
    return instance.valFlagC.call();
  }).then(function(flag){
    console.log("VAL FLAG C: " + flag);
  });
}

function printValFlagsEth(contract){
  contract.then(function(instance){
    return instance.valFlagA.call();
  }).then(function(flag){
    console.log("VAL FLAG A: " + web3.fromWei(flag, 'ether'));
  });

  contract.then(function(instance){
    return instance.valFlagB.call();
  }).then(function(flag){
    console.log("VAL FLAG B: " + web3.fromWei(flag, 'ether'));
  });

  contract.then(function(instance){
    return instance.valFlagC.call();
  }).then(function(flag){
    console.log("VAL FLAG C: " + web3.fromWei(flag, 'ether'));
  });
}
