# RealtyHub, A RWA real estate platform
========================================

RealtyHub is a decentralized RWA real estate tranaction platform built on the Binance Smart Chain blockchain. It allows users to buy, sell, and trade fractional ownership of properties in a secure and transparent manner.


## Features

* **Decentralized Marketplace**: The marketplace is built on the Ethereum blockchain, ensuring that all transactions are secure, transparent, and tamper-proof.
* **Fractional Ownership**: Users can buy and sell fractional ownership of properties, making it more accessible and affordable for a wider range of investors.
* **Smart Contracts**: The marketplace uses smart contracts to automate the buying and selling process, ensuring that all transactions are executed correctly and efficiently.
* **Multi-Role Access Control**: The marketplace has a built-in access control system, allowing different roles (e.g. admin, minter, buyer, seller) to perform specific actions.

## Contracts

The project consists of several smart contracts:

* **tBUSD.sol**: testnet BUSD token, currency used to for the transactions on the marketplace
* **Property_NFT.sol**: This contract represents a property as a non-fungible token (NFT) and manages its ownership and transfer.
* **Marketplace.sol**: This contract manages the buying and selling of properties, including the creation of listings, bidding, and settlement.
* **RWA_Marketplace_Fractional.sol**: This contract manages the buying and selling of fractional ownership of properties.

## Installation

To use the marketplace, follow these steps:

1. Clone the repository and navigate to the project directory.
2. Create a `.env` file, copy the content of `.en.example` into .env and file in your wallet PRIVATE_KEY and BscScan api
3. Install dependencies by running `npm install` or `yarn install`.
4. Compile the contracts by running `npx hardhat compile`.
5. Deploy the contracts to BNB chain testnet by running `npx hardhat ignition deploy ignition/modules/<module_name> --network BSC_Testnet --verify`.


## Contributing

Contributions are welcome! If you'd like to contribute to the project, please fork the repository and submit a pull request with your changes.
