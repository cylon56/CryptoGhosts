pragma solidity ^0.4.15;

contract CryptoGhostsMarket {

    address owner;

    string public standard = 'CryptoPunks';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    uint public nextGhostIndexToAssign = 0;

    bool public allGhostsAssigned = false;
    uint public ghostsRemainingToAssign = 0;

    //mapping (address => uint) public addressToGhostIndex;
    mapping (uint => address) public ghostIndexToAddress;
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;

    struct Offer {
        bool isForSale;
        uint ghostIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint ghostIndex;
        address bidder;
        uint value;
    }

    // A record of ghosts that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Offer) public ghostsOfferedForSale;
    // A record of the highest ghost bid
    mapping (uint => Bid) public ghostBids;

    mapping (address => uint) public pendingWithdrawals;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    } 

    modifier onlyOpenMarket {
        require(allGhostsAssigned);
        _;
    } 

    event Assign(address indexed to, uint256 ghostIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event GhostTransfer(address indexed from, address indexed to, uint256 ghostIndex);
    event GhostOffered(uint indexed ghostIndex, uint minValue, address indexed toAddress);
    event GhostBidEntered(uint indexed ghostIndex, uint value, address indexed fromAddress);
    event GhostBidWithdrawn(uint indexed ghostIndex, uint value, address indexed fromAddress);
    event GhostBought(uint indexed ghostIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event GhostNoLongerForSale(uint indexed ghostIndex);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CryptoGhostsMarket() 
        payable 
    {
        //balanceOf[msg.sender] = initialSupply;              // Give the creator all initial tokens
        owner = msg.sender;
        totalSupply = 5000;                        // Update total supply
        ghostsRemainingToAssign = totalSupply;
        name = "CRYPTOGHOSTS";                                   // Set the name for display purposes
        symbol = "CG";                               // Set the symbol for display purposes
        decimals = 0;                                       // Amount of decimals for display purposes
    }

    function setInitialOwner(address to, uint ghostIndex) 
        public
        onlyOwner
    {
        require(!allGhostsAssigned);
        require(ghostIndex < 5000);
        if (ghostIndexToAddress[ghostIndex] != to) {
            if (ghostIndexToAddress[ghostIndex] != 0x0) {
                balanceOf[ghostIndexToAddress[ghostIndex]]--;
            } else {
                ghostsRemainingToAssign--;
            }
            ghostIndexToAddress[ghostIndex] = to;
            balanceOf[to]++;
            Assign(to, ghostIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) 
        public
        onlyOwner
    {
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }

    function allInitialOwnersAssigned() 
        public
        onlyOwner
    {
        allGhostsAssigned = true; //once all intial owners are assigned, open the market
    }

    function getGhost(uint ghostIndex) 
        public
        onlyOpenMarket
    {
        require(ghostsRemainingToAssign != 0);
        require(ghostIndex < 5000);
        require(ghostIndexToAddress[ghostIndex] == 0x0);
        ghostIndexToAddress[ghostIndex] = msg.sender;
        balanceOf[msg.sender]++;
        ghostsRemainingToAssign--;
        Assign(msg.sender, ghostIndex);
    }

    // Transfer ownership of a ghost to another user without requiring payment
    function transferGhost(address to, uint ghostIndex) 
        public
        onlyOpenMarket
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] == msg.sender);
        if (ghostsOfferedForSale[ghostIndex].isForSale) {
            ghostNoLongerForSale(ghostIndex);
        }
        ghostIndexToAddress[ghostIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, 1);
        GhostTransfer(msg.sender, to, ghostIndex);
        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid storage bid = ghostBids[ghostIndex];
        if (bid.bidder == to) {
            // Kill bid and refund value
            pendingWithdrawals[to] += bid.value;
            ghostBids[ghostIndex] = Bid(false, ghostIndex, 0x0, 0);
        }
    }

    function ghostNoLongerForSale(uint ghostIndex)
        public
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] == msg.sender); // Only owner can remove from sale
        ghostsOfferedForSale[ghostIndex] = Offer(false, ghostIndex, msg.sender, 0, 0x0);
        GhostNoLongerForSale(ghostIndex);
    }

    function offerGhostForSale(uint ghostIndex, uint minSalePriceInWei)
        public
        onlyOpenMarket
    {
        require(ghostIndexToAddress[ghostIndex] == msg.sender); // Only owner can offer for sale
        require(ghostIndex < totalSupply);
        ghostsOfferedForSale[ghostIndex] = Offer(true, ghostIndex, msg.sender, minSalePriceInWei, 0x0);
        GhostOffered(ghostIndex, minSalePriceInWei, 0x0);
    }

    function offerGhostForSaleToAddress(uint ghostIndex, uint minSalePriceInWei, address toAddress)
        public
        onlyOpenMarket
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] == msg.sender);
        ghostsOfferedForSale[ghostIndex] = Offer(true, ghostIndex, msg.sender, minSalePriceInWei, toAddress);
        GhostOffered(ghostIndex, minSalePriceInWei, toAddress);
    }

    function buyGhost(uint ghostIndex) 
        public
        payable
        onlyOpenMarket
    {
        require(ghostIndex < totalSupply);
        require(offer.isForSale);                // ghost actually for sale
        require(offer.onlySellTo == 0x0 || offer.onlySellTo == msg.sender);  // ghost supposed to be sold to this user
        require(msg.value >= offer.minValue);      // Send enough ETH?
        require(offer.seller == ghostIndexToAddress[ghostIndex]); // Seller is owner of ghost

        Offer offer = ghostsOfferedForSale[ghostIndex];
        address seller = offer.seller;

        ghostIndexToAddress[ghostIndex] = msg.sender;
        balanceOf[seller]--;
        balanceOf[msg.sender]++;
        Transfer(seller, msg.sender, 1);

        ghostNoLongerForSale(ghostIndex);
        pendingWithdrawals[seller] += msg.value;
        GhostBought(ghostIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = ghostBids[ghostIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            ghostBids[ghostIndex] = Bid(false, ghostIndex, 0x0, 0);
        }
    }

    function withdraw() 
        public
        onlyOpenMarket
    {
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function enterBidForGhost(uint ghostIndex) 
        public
        payable
        onlyOpenMarket 
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] != 0x0);
        require(ghostIndexToAddress[ghostIndex] != msg.sender); // Can't bid on your own ghost
        require(msg.value > 0); // Can't bid 0
        Bid existing = ghostBids[ghostIndex];
        require(msg.value > existing.value); // Th new bid is actually greater than previous
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        ghostBids[ghostIndex] = Bid(true, ghostIndex, msg.sender, msg.value);
        GhostBidEntered(ghostIndex, msg.value, msg.sender);
    }

    function acceptBidForGhost(uint ghostIndex, uint minPrice) 
        public
        onlyOpenMarket
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] == msg.sender); // Only owner can accept a bid
        address seller = msg.sender;
        Bid bid = ghostBids[ghostIndex];
        require(bid.value != 0); // Can't sell to a 0 bid
        require(bid.value >= minPrice); // Can't sell to bid below min price

        ghostIndexToAddress[ghostIndex] = bid.bidder;
        balanceOf[seller]--;
        balanceOf[bid.bidder]++;
        Transfer(seller, bid.bidder, 1);

        ghostsOfferedForSale[ghostIndex] = Offer(false, ghostIndex, bid.bidder, 0, 0x0);
        uint amount = bid.value;
        ghostBids[ghostIndex] = Bid(false, ghostIndex, 0x0, 0);
        pendingWithdrawals[seller] += amount;
        GhostBought(ghostIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForGhost(uint ghostIndex) 
        public
        onlyOpenMarket
    {
        require(ghostIndex < totalSupply);
        require(ghostIndexToAddress[ghostIndex] != 0x0); // Ghost has an owner
        require(ghostIndexToAddress[ghostIndex] != msg.sender); // Owner can't withdraw bid (owner can't bid to begin with)
        Bid bid = ghostBids[ghostIndex];
        require(bid.bidder == msg.sender); // original bidder only can withdraw his bid
        GhostBidWithdrawn(ghostIndex, bid.value, msg.sender);
        uint amount = bid.value;
        ghostBids[ghostIndex] = Bid(false, ghostIndex, 0x0, 0);
        // Refund the bid money
        msg.sender.transfer(amount);
    }
}
