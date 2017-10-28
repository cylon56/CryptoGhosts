pragma solidity ^0.4.15;

contract Cryptoghosts {

    address public owner;
    address public minter;
    string public name;
    uint public totalSupply;
    uint public remainingUnassigned;
    //
    uint public devCounter;

    mapping (bytes32 => address) public ghostToOwner;
    mapping (address => uint) public ghostBalances;
    mapping (bytes32 => Offer) public ghostsForSale;
    mapping (bytes32 => Bid) public ghostBids;
    mapping (address => uint) public escrowedBids;
    //
    mapping (uint => bytes32) public devMap;

    struct Offer {
        bool isForSale;
        uint minVal;
        address onlySellTo;
    }

    struct Bid {
        address bidder;
        uint bidVal;
    }


  event Claim(address indexed claimedBy, bytes32 indexed ghostHash);
  event Give(address indexed from, address indexed to, bytes32 indexed ghostHash);
  event GhostTransfer(address indexed from, address indexed to, bytes32 ghostHash);
  event GhostOffered(bytes32 indexed ghostHash, uint minValue, address indexed toAddress);
  event GhostBidEntered(bytes32 indexed ghostHash, uint value, address indexed fromAddress);
  event GhostBidWithdrawn(bytes32 indexed ghostHash);
  event GhostBought(bytes32 indexed ghostHash, uint value, address indexed fromAddress, address indexed toAddress);
  event GhostNoLongerForSale(uint indexed ghostIndex);


//For deployment, do not set minter and owner as same address;
  function Cryptoghosts() {
      owner = msg.sender;
      minter = msg.sender;
      name = "Cryptoghosts";
      totalSupply = 50;
      remainingUnassigned = 50;
      //
      devCounter = 1;
  }

  function safeAdd(uint x, uint y) private returns (uint z) {
    z = x + y;
    assert((z - x) == y);
    return z;
  }

  function safeSub(uint p, uint q) private returns (uint r) {
    require(q <= p);
    return p - q;
  }

  function claimGhost(bytes32 _ghostHash, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool success) {
      require(ecrecover(_ghostHash, _v, _r, _s) == minter);
      require(ghostToOwner[_ghostHash] == 0x0);
      require(ghostBalances[msg.sender] <= 3);
      require(remainingUnassigned > 0);
      ghostToOwner[_ghostHash] = msg.sender;
      ghostBalances[msg.sender] ++;
      remainingUnassigned --;
      Claim(msg.sender, _ghostHash);
      return true;
  }

  function devAssign(bytes32 _seedHash) public returns (bool success) {
      devMap[devCounter] = _seedHash;
      ghostToOwner[_seedHash] = owner;
      while(devCounter < totalSupply && msg.gas > 100000) {
          bytes32 loopHash = sha3(devMap[devCounter]);
          devCounter++;
          devMap[devCounter] = loopHash;
          ghostToOwner[loopHash] = owner;
          remainingUnassigned --;
          ghostBalances[owner] ++;
      }
      return true;
  }

  //Give a ghost you own to someone for free
  function giftGhost(bytes32 _ghostHash, address _to) public returns (bool success) {
    require(ghostToOwner[_ghostHash] == msg.sender);
    ghostToOwner[_ghostHash] = _to;
    GhostTransfer(msg.sender, _to, _ghostHash);
    ghostBalances[msg.sender] --;
    ghostBalances[_to] ++;
    return true;
  }



  //For sellers: Put one of your ghosts up for sale with specified conditions
  function sellGhost(bytes32 _ghostHash, uint _askingPrice) public returns (bool success) {
      require(ghostToOwner[_ghostHash] == msg.sender);
      require(ghostsForSale[_ghostHash].isForSale == false);
      ghostsForSale[_ghostHash] = Offer(true, _askingPrice, 0x0);
      GhostOffered(_ghostHash, _askingPrice, 0x0);
      return true;
  }

  //For sellers: sell a ghost you own only to a specified address
  function sellGhostLimited(bytes32 _ghostHash, uint _askingPrice, address _onlySellTo) public returns (bool success) {
      require(ghostToOwner[_ghostHash] == msg.sender);
      require(ghostsForSale[_ghostHash].isForSale == false);
      ghostsForSale[_ghostHash] = Offer(true, _askingPrice, _onlySellTo);
      GhostOffered(_ghostHash, _askingPrice, _onlySellTo);
      return true;
  }

  //For sellers: take a ghost you put up for sale off the market
  function retractSale(bytes32 _ghostHash) public returns (bool success) {
    require(ghostToOwner[_ghostHash] == msg.sender);
    require(ghostsForSale[_ghostHash].isForSale == true);
    ghostsForSale[_ghostHash] = Offer(false, 0, 0x0);
    GhostBidWithdrawn(_ghostHash);
    return true;
  }


  //For buyers: buy a ghost based on conditions stipulated by seller
  function takeOffer(bytes32 _ghostHash) payable public returns (bool success) {
    require(ghostsForSale[_ghostHash].isForSale == true);
    require(ghostsForSale[_ghostHash].onlySellTo == 0x0 || ghostsForSale[_ghostHash].onlySellTo == msg.sender);
    require(ghostsForSale[_ghostHash].minVal <= msg.value);
    address previousOwner = ghostToOwner[_ghostHash];
    ghostBalances[previousOwner] --;
    ghostBalances[msg.sender] ++;
    ghostsForSale[_ghostHash] = Offer(false, 0, 0x0);
    ghostToOwner[_ghostHash] = msg.sender;
    previousOwner.transfer(msg.value);
    return true;
  }

  //For buyers: Propose offer to buy someone else's ghost.
  function makeBid(bytes32 _ghostHash) payable public returns (bool success) {
    require(msg.value > ghostBids[_ghostHash].bidVal);
    require(ghostToOwner[_ghostHash] != 0x0);
    require(ghostToOwner[_ghostHash] != msg.sender);
    escrowedBids[msg.sender] = safeAdd(escrowedBids[msg.sender], msg.value);
    ghostBids[_ghostHash] = Bid(msg.sender, msg.value);
    GhostBidEntered(_ghostHash, msg.value, msg.sender);
    return true;
  }


  //For sellers: accept an offer to buy your ghost at buyers proposed price.
  function acceptBid(bytes32 _ghostHash) public returns (bool success) {
    require(ghostToOwner[_ghostHash] == msg.sender);
    require(ghostBids[_ghostHash].bidder != 0x0);
    address bidderAddr = ghostBids[_ghostHash].bidder;
    uint bidVal = ghostBids[_ghostHash].bidVal;
    ghostBids[_ghostHash] = Bid(0x0, 0);
    ghostsForSale[_ghostHash] = Offer(false, 0, 0x0);
    ghostToOwner[_ghostHash] = bidderAddr;
    escrowedBids[bidderAddr] = safeSub(escrowedBids[bidderAddr], bidVal);
    msg.sender.transfer(bidVal);
    ghostBalances[msg.sender] --;
    ghostBalances[bidderAddr] ++;
    GhostTransfer(msg.sender, bidderAddr, _ghostHash);
    return true;
  }

  //For buyers: withdraw an offer to buy someone's ghost
  function withdrawBid(bytes32 _ghostHash) public returns (bool success) {
    require(ghostBids[_ghostHash].bidder == msg.sender);
    require(escrowedBids[msg.sender] >= ghostBids[_ghostHash].bidVal);
    uint withdrawVal = ghostBids[_ghostHash].bidVal;
    escrowedBids[msg.sender] = safeSub(escrowedBids[msg.sender], withdrawVal);
    ghostBids[_ghostHash] = Bid(0x0, 0);
    msg.sender.transfer(withdrawVal);
    GhostBidWithdrawn(_ghostHash);
    return true;
  }

  //For testing; removes contract from chain state tree data.
  function killContract() public returns (bool success) {
    require(msg.sender == owner);
    selfdestruct(owner);
    return true;
  }

}
