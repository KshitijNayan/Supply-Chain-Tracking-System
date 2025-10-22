Supply chain tracking system

A decentralized application (dApp) designed to track goods or assets across a supply chain network—from manufacturers to distributors, retailers, and end consumers. This system ensures transparency, traceability, and tamper-proof records using Ethereum smart contracts written in Solidity.

<--Key Features-->

Immutable tracking records on the blockchain
Unique product IDs and metadata for each asset
Transfer of ownership between supply chain participants
Event logging (manufacture, dispatch, delivery, etc.)
Real-time asset status and history
Role-based access control (Manufacturer, Transporter, Retailer, Consumer)

<--Tech Stack-->

| Layer           | Tech / Tool                       |
| --------------- | --------------------------------- |
| Smart Contracts | **Solidity**                      |
| Dev Framework   | **Hardhat** / Truffle             |
| Token Standard  | **ERC-721 / ERC-1155** (optional) |
| Access Control  | **Ownable**, Role-based access    |
| Storage         | IPFS (optional)                   |
| Frontend        | React + Ethers.js / Web3.js       |
| Wallets         | MetaMask, WalletConnect           |
| Testing         | Mocha + Chai                      |
| Deployment      | Alchemy / Infura + Hardhat        |


<--Smart Contract Modules-->

SupplyChain.sol
Main logic for tracking product status, transitions, and ownership

Roles.sol (optional or integrated)
Manages roles like manufacturer, transporter, retailer, etc.

ProductNFT.sol (optional)
ERC-721 for unique assets, if NFTs are used to represent items

Utils.sol (optional)
Utility functions, modifiers, and helpers