var CryptoGhostsMarket = artifacts.require("./CryptoGhostsMarket.sol");

module.exports = function(deployer) {
  deployer.deploy(CryptoGhostsMarket);
};
