pragma solidity ^0.4.15;
contract CryptoPunksMarket {

    // You can use this hash to verify the image file containing all the punks
    //string public imageHash = "ac39af4793119ee46bbff351d8cb6b5f23da60222126add4268e261199a2921b";

    address owner;

    string public standard = 'Unnamed Project';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    uint public nextPunkIndexToAssign = 0;

    bool public allPunksAssigned = false;
    uint public punksRemainingToAssign = 0;

    //mapping (address => uint) public addressToPunkIndex;
    mapping (uint => address) public punkIndexToAddress;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;

    struct Offer {
        bool isForSale;
        uint punkIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint punkIndex;
        address bidder;
        uint value;
    }

    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Offer) public punksOfferedForSale;

    // A record of the highest punk bid
    mapping (uint => Bid) public punkBids;

    mapping (address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint256 punkIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event PunkTransfer(address indexed from, address indexed to, uint256 punkIndex);
    event PunkOffered(uint indexed punkIndex, uint minValue, address indexed toAddress);
    event PunkBidEntered(uint indexed punkIndex, uint value, address indexed fromAddress);
    event PunkBidWithdrawn(uint indexed punkIndex, uint value, address indexed fromAddress);
    event PunkBought(uint indexed punkIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event PunkNoLongerForSale(uint indexed punkIndex);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CryptoPunksMarket() payable {
        //balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        owner = msg.sender;
        totalSupply = 10000;                        // Update total supply
        punksRemainingToAssign = totalSupply;
        name = "CRYPTOPUNKS";                                   // Set the name for display purposes
        symbol = "Ͼ";                               // Set the symbol for display purposes
        decimals = 0;                                       // Amount of decimals for display purposes
    }

    function setInitialOwner(address to, uint punkIndex) {
        require(msg.sender == owner);
        require(!allPunksAssigned);
        require(punkIndex < 10000); // Could be assert to incentivize proper calls
        if (punkIndexToAddress[punkIndex] != to) {
            if (punkIndexToAddress[punkIndex] != 0x0) {
                balanceOf[punkIndexToAddress[punkIndex]]--;
            } else {
                punksRemainingToAssign--;
            }
            punkIndexToAddress[punkIndex] = to;
            balanceOf[to]++;
            Assign(to, punkIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) {
        require(msg.sender == owner);
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }

    function allInitialOwnersAssigned() {
        require(msg.sender == owner);
        allPunksAssigned = true;
    }

    function getPunk(uint punkIndex) {
        require(allPunksAssigned); // Can't be called until allInitialOwnersAssigned has done its thing
        require(punksRemainingToAssign != 0);
        require(punkIndex < 10000);
        require(punkIndexToAddress[punkIndex] == 0x0);
        punkIndexToAddress[punkIndex] = msg.sender;
        balanceOf[msg.sender]++;
        punksRemainingToAssign--;
        Assign(msg.sender, punkIndex);
    }

    // Transfer ownership of a punk to another user without requiring payment
    function transferPunk(address to, uint punkIndex) {
        require(allPunksAssigned);
        require(punkIndex < 10000);
        require(punkIndexToAddress[punkIndex] == msg.sender);
        if (punksOfferedForSale[punkIndex].isForSale) {
            punkNoLongerForSale(punkIndex);
        }
        punkIndexToAddress[punkIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, 1);
        PunkTransfer(msg.sender, to, punkIndex);
        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid storage bid = punkBids[punkIndex];
        if (bid.bidder == to) {
            // Kill bid and refund value
            pendingWithdrawals[to] += bid.value;
            punkBids[punkIndex] = Bid(false, punkIndex, 0x0, 0);
        }
    }

    function punkNoLongerForSale(uint punkIndex) {
        require(allPunksAssigned);
        require(punkIndex < 10000);
        require(punkIndexToAddress[punkIndex] == msg.sender); // Only owner can remove from sale
        punksOfferedForSale[punkIndex] = Offer(false, punkIndex, msg.sender, 0, 0x0);
        PunkNoLongerForSale(punkIndex);
    }

    function offerPunkForSale(uint punkIndex, uint minSalePriceInWei) {
        require(allPunksAssigned);
        require(punkIndexToAddress[punkIndex] == msg.sender); // Only owner can offer for sale
        require(punkIndex < 10000);
        punksOfferedForSale[punkIndex] = Offer(true, punkIndex, msg.sender, minSalePriceInWei, 0x0);
        PunkOffered(punkIndex, minSalePriceInWei, 0x0);
    }

    function offerPunkForSaleToAddress(uint punkIndex, uint minSalePriceInWei, address toAddress) {
        require(allPunksAssigned);
        require(punkIndex < 10000);
        require(punkIndexToAddress[punkIndex] == msg.sender);
        punksOfferedForSale[punkIndex] = Offer(true, punkIndex, msg.sender, minSalePriceInWei, toAddress);
        PunkOffered(punkIndex, minSalePriceInWei, toAddress);
    }

    function buyPunk(uint punkIndex) payable {
        require(allPunksAssigned);
        require(punkIndex < 10000);
        require(offer.isForSale);                // punk actually for sale
        require(offer.onlySellTo == 0x0 || offer.onlySellTo == msg.sender);  // punk supposed to be sold to this user
        require(msg.value >= offer.minValue);      // Send enough ETH?
        require(offer.seller == punkIndexToAddress[punkIndex]); // Seller is owner of punk

        Offer offer = punksOfferedForSale[punkIndex];
        address seller = offer.seller;

        punkIndexToAddress[punkIndex] = msg.sender;
        balanceOf[seller]--;
        balanceOf[msg.sender]++;
        Transfer(seller, msg.sender, 1);

        punkNoLongerForSale(punkIndex);
        pendingWithdrawals[seller] += msg.value;
        PunkBought(punkIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = punkBids[punkIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            punkBids[punkIndex] = Bid(false, punkIndex, 0x0, 0);
        }
    }

    function withdraw() {
        require(allPunksAssigned);
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function enterBidForPunk(uint punkIndex) payable {
        require(punkIndex < 10000);
        require(allPunksAssigned);
        require(punkIndexToAddress[punkIndex] != 0x0);
        require(punkIndexToAddress[punkIndex] != msg.sender); // Can't bid on your own punk
        require(msg.value > 0); // Can't bid 0
        Bid existing = punkBids[punkIndex];
        require(msg.value > existing.value); // Th new bid is actually greater than previous
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        punkBids[punkIndex] = Bid(true, punkIndex, msg.sender, msg.value);
        PunkBidEntered(punkIndex, msg.value, msg.sender);
    }

    function acceptBidForPunk(uint punkIndex, uint minPrice) {
        require(punkIndex < 10000);
        require(allPunksAssigned);
        require(punkIndexToAddress[punkIndex] == msg.sender); // Only owner can accept a bid
        address seller = msg.sender;
        Bid bid = punkBids[punkIndex];
        require(bid.value != 0); // Can't sell to a 0 bid
        require(bid.value >= minPrice); // Can't sell to bid below min price

        punkIndexToAddress[punkIndex] = bid.bidder;
        balanceOf[seller]--;
        balanceOf[bid.bidder]++;
        Transfer(seller, bid.bidder, 1);

        punksOfferedForSale[punkIndex] = Offer(false, punkIndex, bid.bidder, 0, 0x0);
        uint amount = bid.value;
        punkBids[punkIndex] = Bid(false, punkIndex, 0x0, 0);
        pendingWithdrawals[seller] += amount;
        PunkBought(punkIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForPunk(uint punkIndex) {
        require(punkIndex < 10000);
        require(allPunksAssigned);
        require(punkIndexToAddress[punkIndex] != 0x0); // Punk has an owner
        require(punkIndexToAddress[punkIndex] != msg.sender); // Owner can't withdraw bid (owner can't bid to begin with)
        Bid bid = punkBids[punkIndex];
        require(bid.bidder == msg.sender); // original bidder only can withdraw his bid
        PunkBidWithdrawn(punkIndex, bid.value, msg.sender);
        uint amount = bid.value;
        punkBids[punkIndex] = Bid(false, punkIndex, 0x0, 0);
        // Refund the bid money
        msg.sender.transfer(amount);
    }
}
