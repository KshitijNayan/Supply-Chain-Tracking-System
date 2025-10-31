// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title SupplyChainTracker
 * @author
 * @notice Simple supply-chain tracking with roles, events and product history.
 * Roles: DEFAULT_ADMIN_ROLE (owner), MANUFACTURER, TRANSPORTER, WAREHOUSE, RETAILER
 *
 * Functions:
 * - createProduct (manufacturer)
 * - assignTransporter / transferOwnership (controlled transitions)
 * - updateLocationAndStatus (by current actor role)
 * - receiveAtWarehouse / deliverToRetailer / recallProduct
 * - view product & history
 *
 * This is a base implementation — extend as per on-chain/off-chain integration,
 * tokenization (ERC721) or privacy needs.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SupplyChainTracker is AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _productIdCounter;

    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant TRANSPORTER_ROLE  = keccak256("TRANSPORTER_ROLE");
    bytes32 public constant WAREHOUSE_ROLE    = keccak256("WAREHOUSE_ROLE");
    bytes32 public constant RETAILER_ROLE     = keccak256("RETAILER_ROLE");

    enum Status { Unknown, Manufactured, InTransit, InWarehouse, Delivered, Recalled }

    struct HistoryItem {
        uint256 timestamp;
        address actor;
        string role;
        string location; // free-form (could be GPS, address, hub id)
        string note;     // e.g., "Loaded", "Checked", "Temp OK"
        Status status;
    }

    struct Product {
        uint256 id;
        string sku;          // product SKU or barcode
        string description;  // free text
        address currentOwner;
        Status status;
        uint256 createdAt;
        // dynamic history stored separately via mapping to save stack complexity
    }

    // productId => Product
    mapping(uint256 => Product) private products;

    // productId => array of history items
    mapping(uint256 => HistoryItem[]) private histories;

    // Events
    event ProductCreated(uint256 indexed productId, string sku, address indexed manufacturer);
    event OwnershipTransferred(uint256 indexed productId, address indexed from, address indexed to, Status status);
    event HistoryAdded(uint256 indexed productId, address indexed actor, string role, string location, string note, Status status);
    event ProductRecalled(uint256 indexed productId, address indexed by, string reason);

    constructor(address admin) {
        // set deployer (or provided admin) as DEFAULT_ADMIN_ROLE
        if (admin == address(0)) {
            admin = msg.sender;
        }
        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        // grant admin all the role-manage permissions by default
        _setRoleAdmin(MANUFACTURER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(TRANSPORTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(WAREHOUSE_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RETAILER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    // ---------- Modifiers ----------
    modifier onlyRoleOrAdmin(bytes32 role) {
        require(hasRole(role, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _;
    }

    modifier productExists(uint256 productId) {
        require(products[productId].id != 0, "Product does not exist");
        _;
    }

    // ---------- Role management helpers (admin-only) ----------
    function grantManufacturer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MANUFACTURER_ROLE, account);
    }
    function grantTransporter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(TRANSPORTER_ROLE, account);
    }
    function grantWarehouse(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(WAREHOUSE_ROLE, account);
    }
    function grantRetailer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(RETAILER_ROLE, account);
    }

    // ---------- Product lifecycle ----------
    /**
     * @notice Manufacturer creates product on-chain.
     * @param sku - SKU / barcode
     * @param description - human readable description
     */
    function createProduct(string calldata sku, string calldata description, string calldata location, string calldata note)
        external
        onlyRoleOrAdmin(MANUFACTURER_ROLE)
        returns (uint256)
    {
        _productIdCounter.increment();
        uint256 newId = _productIdCounter.current();

        products[newId] = Product({
            id: newId,
            sku: sku,
            description: description,
            currentOwner: msg.sender,
            status: Status.Manufactured,
            createdAt: block.timestamp
        });

        // initial history
        histories[newId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: "MANUFACTURER",
            location: location,
            note: note,
            status: Status.Manufactured
        }));

        emit ProductCreated(newId, sku, msg.sender);
        emit HistoryAdded(newId, msg.sender, "MANUFACTURER", location, note, Status.Manufactured);
        return newId;
    }

    /**
     * @notice Transfer to a transporter (or any address) - for shipping
     * Caller must be current owner (or admin)
     */
    function transferTo(uint256 productId, address to, string calldata roleLabel, string calldata location, string calldata note)
        external
        productExists(productId)
    {
        Product storage p = products[productId];
        require(msg.sender == p.currentOwner || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only owner or admin can transfer");

        address from = p.currentOwner;
        p.currentOwner = to;
        // conservative status change: InTransit if transporter, else leave Unknown decision to caller
        if (hasRole(TRANSPORTER_ROLE, to)) {
            p.status = Status.InTransit;
        }
        // record history
        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: roleLabel,
            location: location,
            note: note,
            status: p.status
        }));

        emit OwnershipTransferred(productId, from, to, p.status);
        emit HistoryAdded(productId, msg.sender, roleLabel, location, note, p.status);
    }

    /**
     * @notice Update status & location by authorized actors (transporter/warehouse/retailer/manufacturer/admin)
     */
    function updateLocationAndStatus(
        uint256 productId,
        string calldata location,
        string calldata note,
        Status newStatus
    )
        external
        productExists(productId)
    {
        // require that caller has at least one of the expected roles or is the current owner/admin
        bool authorized = hasRole(TRANSPORTER_ROLE, msg.sender)
                          || hasRole(WAREHOUSE_ROLE, msg.sender)
                          || hasRole(RETAILER_ROLE, msg.sender)
                          || hasRole(MANUFACTURER_ROLE, msg.sender)
                          || msg.sender == products[productId].currentOwner
                          || hasRole(DEFAULT_ADMIN_ROLE, msg.sender);

        require(authorized, "Not authorized to update");

        products[productId].status = newStatus;

        // push history
        string memory roleLabel = _detectRoleLabel(msg.sender);
        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: roleLabel,
            location: location,
            note: note,
            status: newStatus
        }));

        emit HistoryAdded(productId, msg.sender, roleLabel, location, note, newStatus);
    }

    /**
     * @notice Mark product as received in a warehouse (warehouse role)
     */
    function receiveAtWarehouse(uint256 productId, string calldata location, string calldata note)
        external
        productExists(productId)
        onlyRoleOrAdmin(WAREHOUSE_ROLE)
    {
        products[productId].status = Status.InWarehouse;
        products[productId].currentOwner = msg.sender;

        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: "WAREHOUSE",
            location: location,
            note: note,
            status: Status.InWarehouse
        }));

        emit OwnershipTransferred(productId, address(0), msg.sender, Status.InWarehouse); // from omitted in event - optional
        emit HistoryAdded(productId, msg.sender, "WAREHOUSE", location, note, Status.InWarehouse);
    }

    /**
     * @notice Deliver to retailer (retailer role)
     */
    function deliverToRetailer(uint256 productId, string calldata location, string calldata note)
        external
        productExists(productId)
        onlyRoleOrAdmin(RETAILER_ROLE)
    {
        products[productId].status = Status.Delivered;
        products[productId].currentOwner = msg.sender;

        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: "RETAILER",
            location: location,
            note: note,
            status: Status.Delivered
        }));

        emit OwnershipTransferred(productId, address(0), msg.sender, Status.Delivered);
        emit HistoryAdded(productId, msg.sender, "RETAILER", location, note, Status.Delivered);
    }

    /**
     * @notice Recall product (admin/manufacturer)
     */
    function recallProduct(uint256 productId, string calldata reason)
        external
        productExists(productId)
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(MANUFACTURER_ROLE, msg.sender), "Only admin/manufacturer can recall");
        products[productId].status = Status.Recalled;

        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: _detectRoleLabel(msg.sender),
            location: "",
            note: reason,
            status: Status.Recalled
        }));

        emit ProductRecalled(productId, msg.sender, reason);
        emit HistoryAdded(productId, msg.sender, _detectRoleLabel(msg.sender), "", reason, Status.Recalled);
    }

    // ---------- Views / getters ----------
    function getProduct(uint256 productId)
        external
        view
        productExists(productId)
        returns (
            uint256 id,
            string memory sku,
            string memory description,
            address currentOwner,
            Status status,
            uint256 createdAt
        )
    {
        Product storage p = products[productId];
        return (p.id, p.sku, p.description, p.currentOwner, p.status, p.createdAt);
    }

    function getHistoryCount(uint256 productId) external view productExists(productId) returns (uint256) {
        return histories[productId].length;
    }

    function getHistoryItem(uint256 productId, uint256 index) external view productExists(productId)
        returns (
            uint256 timestamp,
            address actor,
            string memory role,
            string memory location,
            string memory note,
            Status status
        )
    {
        require(index < histories[productId].length, "Index out of bounds");
        HistoryItem storage h = histories[productId][index];
        return (h.timestamp, h.actor, h.role, h.location, h.note, h.status);
    }

    // helper to bulk-read recent N history items (returns arrays)
    function getRecentHistory(uint256 productId, uint256 count) external view productExists(productId)
        returns (
            uint256[] memory timestamps,
            address[] memory actors,
            string[] memory roles,
            string[] memory locations,
            string[] memory notes,
            Status[] memory statuses
        )
    {
        uint256 total = histories[productId].length;
        if (count > total) count = total;

        timestamps = new uint256[](count);
        actors = new address[](count);
        roles = new string[](count);
        locations = new string[](count);
        notes = new string[](count);
        statuses = new Status[](count);

        uint256 start = total - count;
        for (uint256 i = 0; i < count; i++) {
            HistoryItem storage h = histories[productId][start + i];
            timestamps[i] = h.timestamp;
            actors[i] = h.actor;
            roles[i] = h.role;
            locations[i] = h.location;
            notes[i] = h.note;
            statuses[i] = h.status;
        }
    }

    // ---------- Internal helpers ----------
    function _detectRoleLabel(address account) internal view returns (string memory) {
        if (hasRole(MANUFACTURER_ROLE, account)) return "MANUFACTURER";
        if (hasRole(TRANSPORTER_ROLE, account)) return "TRANSPORTER";
        if (hasRole(WAREHOUSE_ROLE, account)) return "WAREHOUSE";
        if (hasRole(RETAILER_ROLE, account)) return "RETAILER";
        if (hasRole(DEFAULT_ADMIN_ROLE, account)) return "ADMIN";
        return "UNKNOWN";
    }

    // ---------- Emergency / admin ----------
    // Admin can force-update owner/status (use carefully)
    function adminForceUpdateOwnerAndStatus(uint256 productId, address newOwner, Status newStatus)
        external
        productExists(productId)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        products[productId].currentOwner = newOwner;
        products[productId].status = newStatus;

        histories[productId].push(HistoryItem({
            timestamp: block.timestamp,
            actor: msg.sender,
            role: "ADMIN",
            location: "",
            note: "adminForceUpdate",
            status: newStatus
        }));

        emit OwnershipTransferred(productId, address(0), newOwner, newStatus);
        emit HistoryAdded(productId, msg.sender, "ADMIN", "", "adminForceUpdate", newStatus);
    }
}
