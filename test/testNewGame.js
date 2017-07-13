var SpoofOfStake2 = artifacts.require('./SpoofOfStake2.sol');

contract('SpoofOfStake2', function(accounts){
  var SoS2 = SpoofOfStake2.deployed();
  var account_arr = accounts;

  it('should correctly start a new game when the time is up', function(accounts){
    console.log(1)
    SoS2.then(function(instance){
      return instance.isGameRunning.call(0);
    }).then(function(running){
      console.log(2)
      assert.equal(true, running, 'game not running');
      setTimeout(function(){
        console.log(3)
        SoS2.then(function(instance){
          return instance.isGameRunning.call(0);
        }).then(function(running){
          console.log(4)
          assert.equal(false, running, 'game still running');
          SoS2.then(function(instance){
            return instance.startNewGame.call({'from': account_arr[0]});
          }).then(function(ret){
            console.log(5)
            console.log("GAME START: " + ret);
          })
        })
      }, 120000);
    })
  })
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
