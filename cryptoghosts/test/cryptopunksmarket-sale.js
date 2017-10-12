require('babel-polyfill');

var CryptoGhostsMarketSale = artifacts.require("./CryptoGhostsMarket.sol");

var expectThrow = async function (promise) {
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

var compareBalance = function(previousBalance, currentBalance, amount) {
  var strPrevBalance = String(previousBalance);
  var digitsToCompare = 8;
  var subPrevBalance = strPrevBalance.substr(strPrevBalance.length - digitsToCompare, strPrevBalance.length);
  var strBalance = String(currentBalance);
  var subCurrBalance = strBalance.substr(strBalance.length - digitsToCompare, strBalance.length);
  console.log("Comparing only least significant digits: "+subPrevBalance+" vs. "+subCurrBalance);
  assert.equal(Number(subCurrBalance), Number(subPrevBalance) + amount, "Account 1 balance incorrect after withdrawal.");
};

var NULL_ACCOUNT = "0x0000000000000000000000000000000000000000";

contract('CryptoGhostsMarketSale', function (accounts) {
  it("can not offer for sale allGhostsAssigned = false", async function () {
    var contract = await CryptoGhostsMarket.deployed();
    await contract.setInitialOwner(accounts[0], 0);
    var allAssigned = await contract.allGhostsAssigned.call();
    assert.equal(false, allAssigned, "allAssigned should be false to start.");
    await expectThrow(contract.offerGhostForSale(0, 1000));
  }),
    it("can offer a ghost", async function () {
      var contract = await CryptoGhostsMarket.deployed();

      await contract.setInitialOwner(accounts[1], 1);
      await contract.setInitialOwner(accounts[2], 2);
      await contract.allInitialOwnersAssigned();

      await contract.offerGhostForSale(0, 1000);

      var offer = await contract.ghostsOfferedForSale.call(0);
      console.log("Offer: " + offer);
      assert.equal(true, offer[0], "Ghost 0 not for sale");
      assert.equal(0, offer[1]);
      assert.equal(accounts[0], offer[2]);
      assert.equal(1000, offer[3]);
      assert.equal(NULL_ACCOUNT, offer[4]);
    }),
    it("can not buy a ghost that is not for sale", async function () {
      var contract = await CryptoGhostsMarket.deployed();

      await expectThrow(contract.buyGhost(1, 10000000));
    }),
    it("can not buy a ghost for too little money", async function () {
      var contract = await CryptoGhostsMarket.deployed();

      var ethBalance = await web3.eth.getBalance(accounts[1]);
      console.log("Account 1 has " + ethBalance + " Wei");
      assert(ethBalance > 0);
      await expectThrow(contract.buyGhost(0, {from: accounts[1], value: 10}));
    }),
    it("can not offer a ghost with an invalid index", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      await expectThrow(contract.offerGhostForSale(100000, 1000));
    }),
    it("can not buy a ghost with an invalid index", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      await expectThrow(contract.buyGhost(100000, {value: 10000000}));
    }),
    it("can buy a ghost that is for sale", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      await contract.buyGhost(0, {from: accounts[1], value: 1000});

      var offer = await contract.ghostsOfferedForSale.call(0);
      console.log("Offer post purchase: " + offer);
      assert.equal(false, offer[0], "Ghost 0 not for sale");
      assert.equal(0, offer[1]);
      assert.equal(0, offer[3]);
      assert.equal(NULL_ACCOUNT, offer[4]);

      var balance = await contract.balanceOf.call(accounts[0]);
      // console.log("Balance acc0: " + balance);
      assert.equal(balance.valueOf(), 0, "Ghost balance account 0 incorrect");
      var balance1 = await contract.balanceOf.call(accounts[1]);
      // console.log("Balance acc1: " + balance1);
      assert.equal(balance1.valueOf(), 2, "Ghost balance account 1 incorrect");

      var balanceToWidthdraw = await contract.pendingWithdrawals.call(accounts[0]);
      assert.equal(balanceToWidthdraw.valueOf(), 1000, "Balance not available to withdraw.");

    }),
    it("can withdraw money from sale", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      var accountBalancePrev = await web3.eth.getBalance(accounts[0]);
      await contract.withdraw();
      var accountBalance = await web3.eth.getBalance(accounts[0]);
      compareBalance(accountBalancePrev, accountBalance, 1000);

      var balanceToWidthdraw = await contract.pendingWithdrawals.call(accounts[0]);
      assert.equal(balanceToWidthdraw.valueOf(), 0);
    }),
    it("can offer for sale then withdraw", async function () {
      var contract = await CryptoGhostsMarket.deployed();

      await contract.offerGhostForSale(1, 1333, {from: accounts[1]});

      var offer = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer: " + offer);
      assert.equal(true, offer[0]);
      assert.equal(1, offer[1]);
      assert.equal(accounts[1], offer[2]);
      assert.equal(1333, offer[3]);
      assert.equal(NULL_ACCOUNT, offer[4]);

      await contract.ghostNoLongerForSale(1, {from: accounts[1]});

      var offerPost = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer: " + offer);
      assert.equal(false, offerPost[0]);
      assert.equal(1, offerPost[1]);
      assert.equal(accounts[1], offerPost[2]);
      assert.equal(0, offerPost[3]);
      assert.equal(NULL_ACCOUNT, offerPost[4]);

      // Can't buy it either
      await expectThrow(contract.buyGhost(1, {value: 10000000}));

    }),
    it("can offer for sale to specific account", async function () {
      var contract = await CryptoGhostsMarket.deployed();

      await contract.offerGhostForSaleToAddress(1, 1333, accounts[0], {from: accounts[1]});

      var offer = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer: " + offer);
      assert.equal(true, offer[0]);
      assert.equal(1, offer[1]);
      assert.equal(accounts[1], offer[2]);
      assert.equal(1333, offer[3]);
      assert.equal(accounts[0], offer[4]);

      // Account 2 can't buy it
      await expectThrow(contract.buyGhost(1, {from: accounts[2], value: 10000000}));

      // Acccount 0 can though
      await contract.buyGhost(1, {from: accounts[0], value: 1333});

      var offerPost = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer: " + offer);
      assert.equal(false, offerPost[0]);
      assert.equal(1, offerPost[1]);
      assert.equal(accounts[0], offerPost[2]);
      assert.equal(0, offerPost[3]);
      assert.equal(NULL_ACCOUNT, offerPost[4]);

      var balance = await contract.balanceOf.call(accounts[0]);
      // console.log("Balance acc0: " + balance);
      assert.equal(balance.valueOf(), 1, "Ghost balance account 0 incorrect");
      var balance1 = await contract.balanceOf.call(accounts[1]);
      // console.log("Balance acc1: " + balance1);
      assert.equal(balance1.valueOf(), 1, "Ghost balance account 1 incorrect");

      var balanceToWidthdraw = await contract.pendingWithdrawals.call(accounts[1]);
      assert.equal(balanceToWidthdraw.valueOf(), 1333, "Balance not available to withdraw.");

    }),
    it("can withdraw money from sale to specific account", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      var accountBalancePrev = await web3.eth.getBalance(accounts[1]);
      await contract.withdraw({from: accounts[1]});
      var accountBalance = await web3.eth.getBalance(accounts[1]);
      compareBalance(accountBalancePrev, accountBalance, 1333);

      var balanceToWidthdraw = await contract.pendingWithdrawals.call(accounts[1]);
      assert.equal(balanceToWidthdraw.valueOf(), 0);

    }),
    it("transfer should cancel offers", async function () {
      var contract = await CryptoGhostsMarket.deployed();
      await contract.offerGhostForSale(1, 2333);

      var offer = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer: " + offer);
      assert.equal(true, offer[0]);
      assert.equal(1, offer[1]);
      assert.equal(accounts[0], offer[2]);
      assert.equal(2333, offer[3]);
      assert.equal(NULL_ACCOUNT, offer[4]);

      await contract.transferGhost(accounts[1], 1);

      var offer = await contract.ghostsOfferedForSale.call(1);
      console.log("Offer post transfer: " + offer);
      assert.equal(false, offer[0]);
      assert.equal(1, offer[1]);
      assert.equal(accounts[0], offer[2]);
      assert.equal(0, offer[3]);
      assert.equal(NULL_ACCOUNT, offer[4]);

    })


});
