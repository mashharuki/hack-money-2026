// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMockOracle} from "../MockOracle.sol";

/// @title FunctionsReceiver
/// @notice Chainlink Functions 応答を受け取り Oracle 更新につなぐ受信コンポーネント
/// @dev 3.1 では責務分離のためのスケルトンを提供し、request/fulfill の本実装は後続タスクで追加する
contract FunctionsReceiver is Ownable {
    uint256 public constant DEFAULT_MIN_UPKEEP_INTERVAL = 600;

    IMockOracle public immutable oracle;
    bytes32 public donId;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit;
    string public source;
    string[] public args;
    uint256 public minUpkeepInterval;
    uint256 public lastUpkeepTimestamp;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    error InvalidOracleAddress();
    error NotImplemented();

    constructor(address oracle_, bytes32 donId_, uint64 subscriptionId_, uint32 callbackGasLimit_) Ownable(msg.sender) {
        if (oracle_ == address(0)) {
            revert InvalidOracleAddress();
        }
        oracle = IMockOracle(oracle_);
        donId = donId_;
        subscriptionId = subscriptionId_;
        callbackGasLimit = callbackGasLimit_;
        minUpkeepInterval = DEFAULT_MIN_UPKEEP_INTERVAL;
    }

    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = block.timestamp - lastUpkeepTimestamp >= minUpkeepInterval;
        performData = "";
    }

    function performUpkeep(bytes calldata) external {
        revert NotImplemented();
    }

    function setSource(string memory newSource) external onlyOwner {
        source = newSource;
    }

    function setArgs(string[] memory newArgs) external onlyOwner {
        delete args;
        for (uint256 i = 0; i < newArgs.length; i++) {
            args.push(newArgs[i]);
        }
    }

    function setSubscriptionId(uint64 newSubId) external onlyOwner {
        subscriptionId = newSubId;
    }

    function setMinUpkeepInterval(uint256 interval) external onlyOwner {
        minUpkeepInterval = interval;
    }
}
