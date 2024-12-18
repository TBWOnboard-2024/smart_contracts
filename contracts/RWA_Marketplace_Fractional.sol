// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FractionalOwnershipMarketplace is Ownable, Pausable, AccessControl, IERC721Receiver, Initializable {
    
    uint256 public totalShare;
    IERC721 public propertyNFT;
    IERC20 public BUSDtoken;        // BUSD token

    bytes32 public constant LISTER_ROLE = keccak256("LISTER_ROLE");

    struct MarketItem {
        address seller;
        uint256 price;
        address propertyToken;
        uint256 pricePerShare; // Price for each ERC20 token share
        uint256 sharesAvailable;
        uint256 timeListed;  
    }

    mapping(uint256 => MarketItem) public items; // Map listing ID to Listing details

    event PropertyListed(
        address indexed lister,
        uint256 tokenId,
        uint256 price,
        address propertyToken,
        uint256 pricePerShare
    );

    event PropertyBought(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 sharesBought
    );

    constructor() Ownable(msg.sender) {}

    function initialize() initializer external {
        _transferOwnership(_msgSender());
        totalShare = 1000;
        BUSDtoken = IERC20(0x2ad4992E2bFa5440e9CE7C8D4A53bf7C2Eb62A93);
        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(LISTER_ROLE, owner());
    }


    function createProperty(address lister, uint256 _tokenId, uint256 _price) external whenNotPaused {
        require(hasRole(LISTER_ROLE, msg.sender), "createProperty: Caller do not have lister role");

        address realtyHub_Token = address(
            new RealtyHub_Token(
                string.concat("RealtyHub propertyShare ", Strings.toString(_tokenId)), 
                string.concat("PSHARE", Strings.toString(_tokenId)),
                totalShare*10**18,
                address(this)
            )
        );

        items[_tokenId] = MarketItem({
            seller: lister,
            price: _price,
            propertyToken: realtyHub_Token,
            pricePerShare: _price/totalShare,
            sharesAvailable: totalShare,
            timeListed: block.timestamp
        });

        emit PropertyListed(lister, _tokenId, _price, realtyHub_Token, _price/totalShare);
    }


    // Function for buyers to buy shares
    function buyPropertyShare(uint256 _tokenID, uint256 _shares) external {
        MarketItem storage listing = items[_tokenID];
        require(listing.seller != address(0), "buyProperty: Item not listed on the marketplace");
        require(listing.seller != msg.sender, "buyProperty: You cannot buy a item that you listed");
        require(listing.sharesAvailable >= _shares, "Not enough shares available");
        require(BUSDtoken.balanceOf(msg.sender)>=listing.price, "buyProperty:  BUSD balance is insufficent");

        uint256 amounToPay = listing.pricePerShare * _shares;
        require(
            BUSDtoken.transferFrom(msg.sender, address(this), amounToPay),
            "Incorrect payment amount"
        );

        // Transfer shares to the buyer
        RealtyHub_Token(listing.propertyToken).transfer(msg.sender, _shares*10**18);
        listing.sharesAvailable -= _shares;

        emit PropertyBought(_tokenID, msg.sender, _shares);
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

    function withdrawNFT(address to, uint256 _tokenId) external onlyOwner {
        propertyNFT.transferFrom(address(this), to, _tokenId);
    }

    function withdrawBUSD(address to, uint256 amount) external onlyOwner {
        BUSDtoken.transfer(to, amount);
    }

    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function getSharePrice(uint256 _tokenID) external view returns (uint256) {
        MarketItem storage listing = items[_tokenID];
        return listing.price;
    }

    function setBUSDToken(IERC20 _token) external onlyOwner {
        BUSDtoken= IERC20(_token);
    }

    function setPopertyNFT(address _nftAddress) external onlyOwner {
        propertyNFT = IERC721(_nftAddress);
    }

    function setTotalShare(uint256 _total) external onlyOwner {
        totalShare = _total;
    }

    function grantListerRole(address _minter) public onlyOwner {
        _grantRole(LISTER_ROLE, _minter);
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

// Fractional Token Contract
contract RealtyHub_Token is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 amount,
        address marketplace
    ) ERC20(name, symbol) {
        _mint(marketplace, amount); // Mint all shares to the marketplace
    }
}
