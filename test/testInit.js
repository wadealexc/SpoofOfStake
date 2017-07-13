var SpoofOfStake2 = artifacts.require('./SpoofOfStake2.sol');

contract('SpoofOfStake2', function(accounts){
  var SoS2 = SpoofOfStake2.deployed();
  console.log("ACCOUNTS:")
  console.log(accounts);
  var account_arr = accounts;
  /*
  * Testing initial values...
  */
  it('should initialize owner', function(){
    SoS2.then(function(instance){
      // console.log(instance.abi);
      return instance.owner.call();
    }).then(function(owner){
      //console.log("OWNER: " + owner);
      assert.equal(owner, account_arr[0], 'owner not correct');
    });
  });

  it('should correctly initialize treasury to 0', function(){
    SoS2.then(function(instance){
      return instance.treasury.call();
    }).then(function(treasury){
      //console.log("TREASURY INIT TO: " + treasury.valueOf());
      assert.equal(0, treasury.valueOf(), 'treasury not 0');
    });
  });

  it('should correctly initialize percents', function(){
    SoS2.then(function(instance){
      return instance.house_cut_percent.call();
    }).then(function(percent){
      //console.log("HOUSE CUT PERCENT: " + percent.valueOf());
      assert.equal(4, percent.valueOf(), 'did not init house cut to 4');
    });
    SoS2.then(function(instance){
      return instance.startgame_bounty_percent.call();
    }).then(function(bounty){
      //console.log("BOUNTY PERCENT: " + bounty.valueOf());
      assert.equal(1, bounty.valueOf(), 'did not init bounty perc to 1');
    });
  });

  /*
  * Testing a few getters
  */
  it('should test if the game is running', function(){
    SoS2.then(function(instance){
      return instance.isGameRunning.call();
    }).then(function(gamerunning){
      //console.log("GAME RUNNING: " + gamerunning);
      assert.equal(true, gamerunning, 'game is not running');
    });
  });

  it('should have 0 in the first game', function(){
    SoS2.then(function(instance){
      return instance.getTotalInGame.call(0);
    }).then(function(total){
      //console.log("TOTAL IN GAME: " + total.valueOf());
      assert.equal(total.valueOf(), 0, 'the game has eth in it!');
    });
  });

  /*
  * Test a few transactions
  */
  it('should deposit properly', function(){
    SoS2.then(function(instance){
      return instance.back('A', {'from': account_arr[0], 'value':500});
    }).then(function(tx){
      //Check that games[gameid].backers[msg.sender].amtA updates
      SoS2.then(function(instance){
        return instance.getMyAmtInA.call(0, {'from': account_arr[0]});
      }).then(function(amt){
        //console.log(account_arr[0] + '-');
        //console.log("BACKED A FOR: " + amt);
        assert.equal(amt.valueOf(), 500, 'back amount not 500');
      });

      //Check that games[gameid].totalInGame updates
      SoS2.then(function(instance){
        return instance.getTotalInGame.call(0);
      }).then(function(total){
        //console.log("GAMETOT: " + total);
        assert.equal(500, total.valueOf(), 'Game.totalInGame did not update');
      });

      //Check that games[gameid].totalInA updates
      SoS2.then(function(instance){
        return instance.getTotalInA.call(0);
      }).then(function(total){
        //console.log("TOT IN A: " + total);
        assert.equal(500, total.valueOf(), 'Game.totalInA did not update');
      });
      //===================
      //Try another backer:
      //===================
      SoS2.then(function(instance){
        return instance.back('A', {'from': account_arr[1], 'value': 100});
      }).then(function(tx){
        //Check that games[gameid].backers[msg.sender].amtA updates
        SoS2.then(function(instance){
          return instance.getMyAmtInA.call(0, {'from':account_arr[1]});
        }).then(function(backAmt){
          //console.log(account_arr[1] + "-");
          //console.log("BACKED A FOR: " + backAmt);
          assert.equal(backAmt.valueOf(), 100, 'amtA did not update');
        });

        //Check that games[gameid].totalInGame updates
        SoS2.then(function(instance){
          return instance.getTotalInGame.call(0);
        }).then(function(total){
          //console.log("GAMETOT: " + total);
          assert.equal(600, total.valueOf(), 'Game.totalInGame did not update');
        });

        //Check that games[gameid].totalInA updates
        SoS2.then(function(instance){
          return instance.getTotalInA.call(0);
        }).then(function(total){
          //console.log("TOT IN A: " + total);
          assert.equal(600, total.valueOf(), 'Game.totalInA did not update');
        });
        //===================
        //Try another backer:
        //===================
        SoS2.then(function(instance){
          return instance.back('B', {'from': account_arr[2], 'value': 300});
        }).then(function(tx){
          //Check that games[gameid].backers[msg.sender].amtB updates
          SoS2.then(function(instance){
            return instance.getMyAmtInB.call(0, {'from':account_arr[2]});
          }).then(function(backAmt){
            //console.log(account_arr[2] + "-");
            //console.log("BACKED B FOR: " + backAmt);
            assert.equal(backAmt.valueOf(), 300, 'amtB did not update');
          });

          //Check that games[gameid].totalInGame updates
          SoS2.then(function(instance){
            return instance.getTotalInGame.call(0);
          }).then(function(total){
            //console.log("GAMETOT: " + total);
            assert.equal(900, total.valueOf(), 'Game.totalInGame did not update');
          });

          //Check that games[gameid].totalInB updates
          SoS2.then(function(instance){
            return instance.getTotalInB.call(0);
          }).then(function(total){
            //console.log("TOT IN B: " + total);
            assert.equal(300, total.valueOf(), 'Game.totalInB did not update');
          });
        });
      });
    });
  });
});

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
