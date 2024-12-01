// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Marketplace_RealEstate is Ownable, ReentrancyGuard, Pausable, AccessControl, IERC721Receiver, Initializable {

    IERC721 public propertyNFT;
    address public taxReceiver;     // Address to receive taxes
    IERC20 public BUSDtoken;        // BUSD token
    uint256 public taxFees;         // Listing fees
    bool public isTax;              // Tax switch
    uint256 public periodInMonth;   // Installment period 60 months
    uint256 public percentage_downPayment;      // Percentage downpayment

    bytes32 public constant LISTER_ROLE = keccak256("LISTER_ROLE");

    struct MarketItem {
        address seller;             // Seller address
        address buyer;              // Buyer address
        uint256 price;              // Listed price
        uint256 timeListed;               // listing time
        bool canBid;                // Auction switch
        address highestBidder;      // Highest bidder
        uint256 highestBid;         // Highest bid amount
    }

    struct InstallmentData {
        uint256 downPayment;
        uint256 monthlyAmount;
        uint256 remainingAmount;
        uint256 paidAmount;
        uint256 paymentDeadline;
    }

    mapping(uint256 => MarketItem) public items; // property listing
    mapping(uint256 => InstallmentData) public installment; // property listing

    event BuyProperty(address indexed buyer, uint256 tokenId, uint256 price);
    event PropertyListed(address indexed seller, uint256 tokenId, uint256 price, bool canBid);
    event CancelSelling(address indexed seller, uint256 tokenId);
    event PriceUpdated(address indexed seller, uint256 tokenId, uint256 price);
    event BidPlaced(uint256 tokenId, address indexed bidder, uint256 amount);
    event BidAccepted(uint256 tokenId, address indexed seller, address indexed bidder,uint256 amount);
    event BidRejected(uint256 tokenId, address indexed seller, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 tokenId, address indexed bidder, uint256 amount);
    event PaymentMade(address indexed buyer, uint256 tokenId, uint256 _montlyAmount, uint256 _remainingAmount);
    
    constructor() Ownable(msg.sender) {}

    function initialize() initializer external {
        _transferOwnership(_msgSender());
        taxFees= 3;
        periodInMonth = 60; // 5 years = 60 months
        isTax= true;
        taxReceiver = 0x2f9FcE639EfF5A9f707489431DA6F48440d246D8;
        BUSDtoken = IERC20(0x2ad4992E2bFa5440e9CE7C8D4A53bf7C2Eb62A93);
        percentage_downPayment = 20;
        _grantRole(LISTER_ROLE, owner());
    }

    // Buy token on the marketplace
    function buyProperty(uint256 _tokenId, uint256 _price) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(listing.buyer == address(0), "buyProperty: Property already bought");
        require(listing.price == _price, "buyProperty: Wrong price");
        require(listing.seller != address(0), "buyProperty: Item not listed on the marketplace");
        require(listing.seller != msg.sender, "buyProperty: You cannot buy a item that you listed");
        require(BUSDtoken.balanceOf(msg.sender)>=listing.price, "buyProperty:  BUSD balance is insufficent");
        if (isTax) {
            uint256 amountToTaxReceiver = listing.price*taxFees/100;
            uint256 amountToSeller = listing.price-amountToTaxReceiver;
            BUSDtoken.transferFrom(msg.sender, taxReceiver, amountToTaxReceiver);
            BUSDtoken.transferFrom(msg.sender, listing.seller, amountToSeller);
        }
        else {
            BUSDtoken.transferFrom(msg.sender, taxReceiver, listing.price);
        }
        
        if (listing.highestBidder != address(0)){
            BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        }
        propertyNFT.transferFrom(address(this), msg.sender, _tokenId);
        delete items[_tokenId];
        emit BuyProperty(msg.sender, _tokenId, listing.price);
    }
    
    // User list property on the marketplace. For users that already have property NFT
    function listProperty(uint256 _tokenId, uint256 _price, bool _canBid) external whenNotPaused {
        require(_price<BUSDtoken.totalSupply(), "listProperty: The price cannot exceed BUSD total supply");
        require(propertyNFT.ownerOf(_tokenId)==msg.sender, "listProperty: You don't own this NFT property");

        propertyNFT.transferFrom(msg.sender, address(this), _tokenId);
        items[_tokenId] = MarketItem(msg.sender, address(0), _price, block.timestamp, _canBid, address(0), 0);
        emit PropertyListed(msg.sender, _tokenId, _price, _canBid);
    }

    // Create a listing on the marketplace. For users that do not have a property NFT
    function createProperty(address lister, uint256 _tokenId, uint256 _price, bool _canBid) external whenNotPaused {
        require(hasRole(LISTER_ROLE, msg.sender), "createProperty: Caller do not have lister role");
        //require(_price<=BUSDtoken.totalSupply(), "CreateProperty: The price cannot exceed BUSD total supply");

        items[_tokenId] = MarketItem(lister, address(0), _price, block.timestamp, _canBid, address(0), 0);
        emit PropertyListed(lister, _tokenId, _price, _canBid);
    }


    // Update property price on the marketplace
    function updatePrice(uint256 _tokenId, uint256 _price) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(_price < BUSDtoken.totalSupply(), "updatePrice: Price can not exceed BUSD total supply");
        require(items[_tokenId].seller==msg.sender, "updatePrice: You don't own this property NFT in the Market");
        require(listing.buyer == address(0), "updatePrice: Property already bought");
        items[_tokenId].price = _price;
        emit PriceUpdated(msg.sender, _tokenId, _price);
    }

    // @Seller cancel listing and remove property from the marketplace
    function cancelSelling(uint256 _tokenId) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(items[_tokenId].seller==msg.sender, "cancelSelling: You don't own this nft in the Market");
        require(listing.buyer == address(0), "cancelSelling: Property already bought");
        if (listing.highestBidder != address(0)){
            BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        }
        propertyNFT.transferFrom(address(this), msg.sender, _tokenId);
        delete items[_tokenId];
        emit CancelSelling(msg.sender, _tokenId);
    }

    // If applicable, buyer can place a bid
    function placeBid(uint256 _tokenId, uint256 bidAmount) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(listing.buyer == address(0), "placeBid: Property already bought");
        require(listing.canBid, "placeBid: You cannot bid on this token");
        require(bidAmount > listing.highestBid, "placeBid: Bid amount must be higher");
        require(listing.seller != msg.sender, "placeBid: You cannot bid on your own listing");

        if (listing.highestBidder != address(0)) {
            BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        }
        BUSDtoken.transferFrom(msg.sender, address(this), bidAmount);
        items[_tokenId].highestBidder = msg.sender;
        items[_tokenId].highestBid = bidAmount;

        emit BidPlaced(_tokenId, msg.sender, bidAmount);
    }

    //Seller call this function to accept the highest bid 
    function acceptBid(uint256 _tokenId) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(listing.buyer == address(0), "acceptBid: Property already bought");
        require(listing.canBid, "acceptBid: You cannot bid on this token");
        require(listing.highestBidder != address(0), "acceptBid: No bids to accept");
        require(listing.seller == msg.sender, "acceptBid: You afre not the owner of this NFT on the marketplace");
        propertyNFT.transferFrom(address(this), listing.highestBidder, _tokenId);
        if (isTax=true) {
            uint256 amountToTaxReceiver = listing.highestBid*taxFees/100;
            uint256 amountToSeller = listing.highestBid-amountToTaxReceiver;
            BUSDtoken.transfer(taxReceiver, amountToTaxReceiver);
            BUSDtoken.transfer(msg.sender, amountToSeller);
        }
        else {
            BUSDtoken.transfer(msg.sender, listing.highestBid);
        }
        
        delete items[_tokenId];
        emit BidAccepted(_tokenId, msg.sender, listing.highestBidder, listing.highestBid);
    }

    // @Buyer reject bid
    function rejectBid(uint256 _tokenId) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(listing.buyer == address(0), "rejectBid: Property already bought");
        require(listing.canBid, "rejectBid: You cannot bid on this token");
        require(listing.highestBidder != address(0), "rejectBid: No bids to reject");
        require(listing.seller == msg.sender, "rejectBid: You afre not the owner of this NFT on the marketplace");

        BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        // Reset the bid information
        items[_tokenId].highestBidder = address(0);
        items[_tokenId].highestBid = 0;

        emit BidRejected(_tokenId, listing.seller, listing.highestBidder, listing.highestBid);
    }

    // Bidder can withdraw their current bid
    function withdrawBid(uint256 _tokenId) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        require(listing.buyer == address(0), "withdrawBid: Property already bought");
        require(listing.canBid, "withdrawBid: You cannot bid on this token");
        require(listing.highestBidder == msg.sender, "withdrawBid: You are not the highest bidder");
        
        BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        // Clear the bid
        items[_tokenId].highestBidder = address(0);
        items[_tokenId].highestBid = 0;

        emit BidWithdrawn(_tokenId, msg.sender, listing.highestBid);
    }

    function buyWithInstallment(uint256 _tokenId, uint256 _price) external whenNotPaused {
        MarketItem storage listing = items[_tokenId];
        uint256 downPayment = listing.price * percentage_downPayment/100;
        require(listing.buyer == address(0), "buyWithInstallment: Property already bought");
        require(listing.price == _price, "buyWithInstallment: Wrong price");
        require(listing.seller != address(0), "buyWithInstallment: Item not listed on the marketplace");
        require(listing.seller != msg.sender, "buyWithInstallment: You cannot buy a item that you listed");
        require(BUSDtoken.balanceOf(msg.sender) >= downPayment, "makePayment: Your tBUSD balance is insufficent");

         if (isTax) {
            uint256 amountToTaxReceiver = downPayment*taxFees/100;
            uint256 amountToSeller = downPayment-amountToTaxReceiver;
            BUSDtoken.transferFrom(msg.sender, taxReceiver, amountToTaxReceiver);
            BUSDtoken.transferFrom(msg.sender, listing.seller, amountToSeller);
        }
        else {
            BUSDtoken.transferFrom(msg.sender, listing.seller, downPayment);
        }

        if (listing.highestBidder != address(0)){
            BUSDtoken.transfer(listing.highestBidder, listing.highestBid);
        }

        items[_tokenId].buyer = msg.sender;
        installment[_tokenId].downPayment = downPayment;
        installment[_tokenId].paidAmount = downPayment;
        installment[_tokenId].remainingAmount = listing.price - downPayment;
        installment[_tokenId].monthlyAmount = (listing.price - downPayment)/periodInMonth;
        installment[_tokenId].paymentDeadline = block.timestamp + 40 days;

        emit BuyProperty(msg.sender, _tokenId, listing.price);
    }


    function makePayment(uint256 _tokenId) external whenNotPaused nonReentrant {
        MarketItem storage listing = items[_tokenId];
        InstallmentData storage installmentInfo = installment[_tokenId];
        require(listing.buyer == msg.sender, "makePayment: This poperty is not yours");
        require(BUSDtoken.balanceOf(msg.sender) >= installmentInfo.monthlyAmount, "makePayment: Your balance is insufficient");
        require(installmentInfo.paymentDeadline >= block.timestamp, "makePayment: Deadline has passed");
        
        BUSDtoken.transferFrom(msg.sender, listing.seller, installmentInfo.monthlyAmount);
        installment[_tokenId].paidAmount += installmentInfo.monthlyAmount;
        installment[_tokenId].remainingAmount -= installmentInfo.monthlyAmount;
        installment[_tokenId].paymentDeadline += 30 days;

        if (installmentInfo.remainingAmount==0) {
            propertyNFT.transferFrom(address(this), msg.sender, _tokenId);
            delete items[_tokenId];
            delete installment[_tokenId];
        }
        emit PaymentMade(msg.sender, _tokenId, installmentInfo.monthlyAmount, installmentInfo.remainingAmount);
    }

    // Get property market informations
    function getMarketItem(uint256 _tokenId) external view returns(MarketItem memory) {
        MarketItem memory listing = items[_tokenId];
        return listing;
    }

    // Batch get property market informations
    function getBatchMarketItem(uint256[] memory _tokenId) external view returns(MarketItem[] memory) {
        MarketItem[] memory listing = new MarketItem[](_tokenId.length);
        for (uint256 i=0;  i<_tokenId.length ; i++) {
            listing[i] = items[_tokenId[i]];
        }
        return listing;
    }

    function getDownPayment(uint256 _tokenId) external view returns (uint256) {
        MarketItem memory listing = items[_tokenId];
        uint256 downPayment = listing.price * percentage_downPayment/100;
        return downPayment;
    }

    function getMontlyPayment(uint256 _tokenId) external view returns (uint256) {
        MarketItem memory listing = items[_tokenId];
        uint256 downPayment = listing.price * percentage_downPayment/100;
        uint256 monthlyPayment = (listing.price - downPayment)/periodInMonth;
        return monthlyPayment;
    }

    function withdrawNFT(address to, uint256 _tokenId) external onlyOwner {
        propertyNFT.transferFrom(address(this), to, _tokenId);
    }

    function withdrawBUSD(address to, uint256 amount) external onlyOwner {
        BUSDtoken.transfer(to, amount);
    }

    function grantListerRole(address _minter) public onlyOwner {
        _grantRole(LISTER_ROLE, _minter);
    }

    function setBUSDToken(IERC20 _token) external onlyOwner {
        BUSDtoken= IERC20(_token);
    }

    function setIsTax(bool _on) external onlyOwner {
        isTax= _on;
    }

    function setTaxFees(uint256 _taxFees) external onlyOwner {
        taxFees= _taxFees;
    }
    
    function setPeriodInMonth(uint256 _months) external onlyOwner {
        periodInMonth= _months;
    }

    function setTaxReceiver(address _taxReceiver) external onlyOwner {
        taxReceiver= _taxReceiver;
    }

    function setPopertyNFT(address _nftAddress) external onlyOwner {
        propertyNFT = IERC721(_nftAddress);
    }

    function setPercentage_downPayment(uint256 _percent) external onlyOwner {
        percentage_downPayment = _percent;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}