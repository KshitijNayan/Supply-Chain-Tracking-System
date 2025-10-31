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

<--Sample flow (quick)-->

Admin deploy contract (or give admin address in constructor).

Admin grants roles (manufacturer, transporter, warehouse, retailer) to addresses.

Manufacturer calls createProduct(sku, desc, location, note) → product created with id.

Manufacturer transferTo(productId, transporterAddress, "TRANSFER", loc, "Pickup").

Transporter updateLocationAndStatus(productId, loc, "In transit", Status.InTransit) periodically.

Warehouse calls receiveAtWarehouse(productId, loc, "Arrived").

Warehouse transfers to retailer or retailer calls deliverToRetailer.

Admin/manufacturer can recallProduct if needed.


<--Notes, security & extensions-->

Gas: history arrays grow on-chain — long histories cost gas. Consider storing large history off-chain (IPFS) and only storing hashes on-chain.

Privacy: data is public on-chain. For sensitive data, encrypt off-chain and store pointer on-chain.

Tokenization: agar chahiye to each product can be an ERC-721 token (unique IDs) so marketplaces/wallets easily track ownership.

Upgradability: for production, consider proxy patterns (UUPS/Transparent) if you need future upgrades.

Access: currentOwner logic is simple — adjust to business logic (e.g., allow only specific roles to accept deliveries).

Testing: write unit tests (Hardhat/Foundry), simulate role grants and full lifecycle.


<img width="2559" height="1172" alt="image" src="https://github.com/user-attachments/assets/e58e04aa-c337-4d29-8e75-b90c0ca44456" />
