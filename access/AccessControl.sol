// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

contract AccessControl is Context {

    // 合约唯一持有者地址
    address internal _owner;
    // ACL开关，默认启用ACL
    bool internal switchOn = true;
    // 有权限的地址集合
    mapping(address => bool) internal members;

    constructor() {
        _owner = msg.sender;
    }

    // ------- 管理员权限 -------
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    // ------- 铸币权限校验 -------
    modifier mintPermissionVerified() {
        if (switchOn) {
            require(_msgSender() == owner() || members[_msgSender()], "Insufficient permissions");
        }
        _;
    }

    // ACL开关
    function enableACL(bool enable) public {
        switchOn = enable;
    }

    // 合约持有者
    function owner() public view virtual returns (address) {
        return _owner;
    }

    // 添加可铸币账号
    function addPermission(address account) external onlyOwner {
        members[account] = true;
    }

    // 移除可铸币账号
    function removePermission(address account) external onlyOwner {
        delete members[account];
    }

    // 查询某个账号是否有权限铸币
    function ifHasPermission(address account) view external returns (bool) {
        return members[account];
    }

}
