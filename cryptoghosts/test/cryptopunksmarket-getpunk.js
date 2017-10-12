require('babel-polyfill');

var CryptoGhostsMarket = artifacts.require("./CryptoGhostsMarket.sol");

var expectThrow = async function(promise) {
  try {
    await promise;
  } catch (error) {
    // TODO: Check jump destination to destinguish between a throw
    //       and an actual invalid jump.
    const invalidOpcode = error.message.search('invalid opcode') >= 0;
    const invalidJump = error.message.search('invalid JUMP') >= 0;
    // TODO: When we contract A calls contract B, and B throws, instead
    //       of an 'invalid jump', we get an 'out of gas' error. How do
    //       we distinguish this from an actual out of gas event? (The
    //       testrpc log actually show an 'invalid jump' event.)
    const outOfGas = error.message.search('out of gas') >= 0;
    assert(
      invalidOpcode || invalidJump || outOfGas,
      "Expected throw, got '" + error + "' instead",
    );
    return;
  }
  assert.fail('Expected throw not received');
};

contract('CryptoGhostsMarket-getGhost', function (accounts) {
  it("can not get punks while allGhostsAssigned = false", async function () {
    var contract = await CryptoGhostsMarket.deployed();
    var balance = await contract.balanceOf.call(accounts[0]);
    console.log("Pre Balance: " + balance);

    var allAssigned = await contract.allGhostsAssigned.call();
    console.log("All assigned: " + allAssigned);
    assert.equal(false, allAssigned, "allAssigned should be false to start.");
    await expectThrow(contract.getGhost(0));
    var balance = await contract.balanceOf.call(accounts[0]);
    console.log("Balance after fail: " + balance);
  }),
  it("can get a punk but no one else can get it after", async function () {
    var contract = await CryptoGhostsMarket.deployed();

    await contract.allInitialOwnersAssigned();

    await contract.getGhost(0);
    var balance = await contract.balanceOf.call(accounts[0]);
    console.log("Balance: " + balance);
    assert.equal(balance.valueOf(), 1, "Didn't get the initial punk");
    var owner = await contract.punkIndexToAddress.call(0);
    assert.equal(owner, accounts[0], "Ownership array wrong");
    var remaining = await contract.punksRemainingToAssign.call();
    assert.equal(9999, remaining);

    try {
      await contract.getGhost(0);
      assert(false, "Should have thrown exception.");
    } catch (err) {
      // Should catch an exception
    }

    var remainingAfter = await contract.punksRemainingToAssign.call();
    assert.equal(9999, remainingAfter);
    var balanceAfter = await contract.balanceOf.call(accounts[0]);
    assert.equal(1, balanceAfter);

  })
});
