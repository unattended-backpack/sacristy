// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Script, console } from "forge-std/Script.sol";

import { SystemConfig } from "src/l2/l1/SystemConfig.sol";
import { KosherPortal } from "src/l2/l1/KosherPortal.sol";
import { AddressManager } from "src/l2/l1/AddressManager.sol";
import { KosherVerifier } from "src/l2/verifier/KosherVerifier.sol";
import { Proxy } from "src/l2/predeploys/Proxy.sol";
import { ISP1Verifier } from "src/l2/verifier/ISP1Verifier.sol";

/// @title DeployL2Contracts
/// @notice Deploys L1 rollup contracts to any L1 RPC. These contracts are used by the L2 rollup
///         to process deposits, verify withdrawals, and configure the system.
///
///         Usage:
///           forge script script/DeployL2Contracts.s.sol \
///             --rpc-url $L1_RPC --private-key $ADMIN_KEY --broadcast
///
///         Environment variables:
///           BATCHER_PRIVATE_KEY   - Private key of the batch submitter (address derived).
///           SEQUENCER_PRIVATE_KEY - Private key of the sequencer (address derived).
///           BATCH_INBOX_ADDRESS   - Batch inbox address (default: 0xff0000000000000000000000000000000000C9AB).
///           GAS_LIMIT             - L2 gas limit (default: 30000000).
contract DeployL2Contracts is Script {
    function run() public {
        address admin = msg.sender;
        address batcher = vm.addr(vm.envUint("BATCHER_PRIVATE_KEY"));
        address sequencer = vm.addr(vm.envUint("SEQUENCER_PRIVATE_KEY"));
        address batchInbox = vm.envOr("BATCH_INBOX_ADDRESS", address(0xfF0000000000000000000000000000000000C9aB));
        uint64 gasLimit = uint64(vm.envOr("GAS_LIMIT", uint256(30_000_000)));

        vm.startBroadcast();

        // 1. Deploy AddressManager.
        AddressManager addressManager = new AddressManager();
        console.log("AddressManager:", address(addressManager));

        // 2. Deploy SystemConfig behind a proxy.
        SystemConfig systemConfigImpl = new SystemConfig();
        Proxy systemConfigProxy = new Proxy(admin);
        // Point proxy to implementation.
        systemConfigProxy.upgradeTo(address(systemConfigImpl));
        // Initialize via the proxy.
        SystemConfig(address(systemConfigProxy)).initialize(
            admin,                                          // owner
            0,                                              // overhead
            0x00000000000000000000000000000000000000000000000000000a000000000a, // scalar (baseFeeScalar=10, blobBaseFeeScalar=10)
            bytes32(uint256(uint160(batcher))),              // batcherHash
            gasLimit,                                       // gasLimit
            sequencer,                                      // unsafeBlockSigner
            batchInbox                                      // batchInbox
        );
        console.log("SystemConfig (proxy):", address(systemConfigProxy));

        // 3. Deploy KosherVerifier (with a dummy SP1 verifier for testnet).
        // For testnet, we use address(0) as the SP1 verifier — proofs won't be verified.
        KosherVerifier verifier = new KosherVerifier(
            ISP1Verifier(address(0)),   // dummy verifier for testnet
            bytes32(0),                 // aggregation vkey
            bytes32(0),                 // rollup config hash
            bytes32(0),                 // range vkey commitment
            bytes32(0),                 // genesis output root (will be set later)
            0                           // genesis block num
        );
        console.log("KosherVerifier:", address(verifier));

        // 4. Deploy KosherPortal behind a proxy.
        KosherPortal portalImpl = new KosherPortal(address(verifier));
        Proxy portalProxy = new Proxy(admin);
        portalProxy.upgradeTo(address(portalImpl));
        console.log("KosherPortal (proxy):", address(portalProxy));

        vm.stopBroadcast();

        // Output summary for config.star.
        console.log("");
        console.log("=== Deployed L2 Contracts ===");
        console.log("l2_system_config_address:", address(systemConfigProxy));
        console.log("l2_optimism_portal_address:", address(portalProxy));
        console.log("address_manager:", address(addressManager));
        console.log("kosher_verifier:", address(verifier));
    }
}
