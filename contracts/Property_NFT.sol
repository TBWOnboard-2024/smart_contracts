// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface Imarketplace {
    function createProperty (address lister, uint256 _tokenId, uint256 _price, bool _canBid) external;
}

contract RWA_RealEstate_NFT is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Pausable, AccessControl, Initializable {
    
    Imarketplace marketplace;
    
    uint256 private _nextTokenId;
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
    
    constructor() ERC721("TBW24 RealEstate RWA", "PROPERTY")Ownable(msg.sender){}

    function initialize() initializer external {
        _transferOwnership(_msgSender());
        _nextTokenId = 1;
        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(MINTER_ROLE, owner());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(
        uint256 price,
        bool canBid,
        uint256 propertyType,
        string memory physicalAddress,
        uint256 rooms,
        uint256 bathrooms,
        uint256 area    // Area in sqm
    ) public {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        marketplace.createProperty(msg.sender, tokenId, price, canBid);
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
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        require(!_blacklist[auth], "_update: Sender is blacklisted");
        require(!_blacklist[to], "_update: Recipient is blacklisted");
        require(auth== address(marketplace) || to==address(marketplace) , "_update: Not allowed to transfer this NFT");
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}