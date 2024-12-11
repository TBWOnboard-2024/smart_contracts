// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface Imarketplace {
    function createProperty (address lister, uint256 _tokenId, uint256 _price) external;
    function createProperty (address lister, uint256 _tokenId, uint256 _price, bool _canBid) external;
}

contract Property_NFT is Initializable, OwnableUpgradeable, ERC721Upgradeable, 
    ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, 
    ERC721PausableUpgradeable, AccessControlUpgradeable {
    
    Imarketplace public marketplace;
    Imarketplace public fractionalMarketplace;
    
    uint256 private _nextTokenId;
    uint256 private _nextFracTokenId;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct Feature {   
        uint256 propertyType; // 1= appartment, 2= house
        string physicalAddress;
        uint256 rooms;
        uint256 bathrooms;
        uint256 area;
    }

    mapping(uint256 => Feature) public propertyFeature;
    mapping(address => bool) private _blacklist;

    event Minted(address to, uint256 tokenId);
    event BatchMinted(address to, uint256[] tokenId);
    event Burned(address user, uint256 tokenId);
    event BatchBurned(uint256[] tokenId);


    function initialize() initializer external {
        __Ownable_init(msg.sender);
        __ERC721_init("TBW24 RealEstate RWA", "PROPERTY");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC721Pausable_init();
        __AccessControl_init();

        _nextTokenId = 1;
        _nextFracTokenId = 10000001;
        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(MINTER_ROLE, owner());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function createProperty(
        uint256 price,
        bool canBid,
        uint256 propertyType,
        string memory physicalAddress,
        uint256 rooms,
        uint256 bathrooms,
        uint256 area    // Area in sqm
    ) public {
        uint256 tokenId = _nextTokenId++;
        _safeMint(address(marketplace), tokenId);
        marketplace.createProperty(msg.sender, tokenId, price, canBid);
        propertyFeature[tokenId]= Feature(propertyType, physicalAddress, rooms, bathrooms, area);
        emit Minted(msg.sender, tokenId);
    }

    function createPropertyShared(
        uint256 price,
        uint256 propertyType,
        string memory physicalAddress,
        uint256 rooms,
        uint256 bathrooms,
        uint256 area    // Area in sqm
    ) public {
        uint256 tokenId = _nextFracTokenId++;
        _safeMint(address(fractionalMarketplace), tokenId);
        fractionalMarketplace.createProperty(msg.sender, tokenId, price);
        propertyFeature[tokenId]= Feature(propertyType, physicalAddress, rooms, bathrooms, area);
        emit Minted(msg.sender, tokenId);
    }

    function burn(uint256 tokenId) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        address user = ownerOf(tokenId);
        _update(address(0), tokenId, user);
        emit Burned(user, tokenId);
    }

    function burnBatch(uint256[] memory tokenIds) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            address user = ownerOf(tokenIds[i]);
            _update(address(0), tokenIds[i], user);
        }
        emit BatchBurned(tokenIds);
    }

    function tokensByAddress(address _account) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_account);
        uint256[] memory tokenIDs = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIDs[i] = tokenOfOwnerByIndex(_account, i);
        }
        return tokenIDs;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _setTokenURI(tokenId, _tokenURI);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        require(!_blacklist[auth], "_update: Sender is blacklisted");
        require(!_blacklist[to], "_update: Recipient is blacklisted");
        require(auth==address(marketplace) || to==address(marketplace) || auth==address(fractionalMarketplace) || to==address(fractionalMarketplace), "_update: Not allowed to transfer this NFT");
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function grantMinterRole(address _minter) public onlyOwner {
        _grantRole(MINTER_ROLE, _minter);
    }

    function isBlackListed(address _account) external view returns(bool) {
        return _blacklist[_account];
    }

    function addToBlacklist(address _account) external onlyOwner {
        require(!_blacklist[_account], "Address is already blacklisted");
        _blacklist[_account] = true;
    }

    function removeFromBlacklist(address _account) external onlyOwner {
        require(_blacklist[_account], "Address is not blacklisted");
        _blacklist[_account] = false;
    }

    function getNextTokenId() external view returns(uint256) {
        return _nextTokenId;
    }

    function setMarketplaceAddress(address _marketAddress) external onlyOwner {
        marketplace = Imarketplace(_marketAddress);
    }

    function setFractionalMarketplace(address _marketAddress) external onlyOwner {
        fractionalMarketplace = Imarketplace(_marketAddress);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}