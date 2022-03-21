// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "./utils/Address.sol";
import "./utils/Context.sol";
import "./utils/introspection/ERC165.sol";
import "./access/AccessControl.sol";

// 主合约
contract Token1155 is Context, ERC165, IERC1155, IERC1155MetadataURI, AccessControl {
    using Address for address;

    // 代币id ==> (账户地址 --> 持有个数)
    mapping(uint256 => mapping(address => uint256)) private _balances;
    // 原持有人地址 ==> (授权地址 --> 授权状态T/F)
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // 授权部分数量
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _approvalCounts;
    mapping(uint256 => string) internal idToUri;

    string private _name;   // 代币名
    string private _symbol; // 代币符号

    // ------- 错误信息 -------
    // 
    // ERC1155: caller is not owner or approved amount insufficient     你不是代币持有者或被授权的可使用数量不足
    string constant Permission_Insufficient = "\xE4\xBD\xA0\xE4\xB8\x8D\xE6\x98\xAF\xE4\xBB\xA3\xE5\xB8\x81\xE6\x8C\x81\xE6\x9C\x89\xE8\x80\x85\xE6\x88\x96\xE8\xA2\xAB\xE6\x8E\x88\xE6\x9D\x83\xE7\x9A\x84\xE5\x8F\xAF\xE4\xBD\xBF\xE7\x94\xA8\xE6\x95\xB0\xE9\x87\x8F\xE4\xB8\x8D\xE8\xB6\xB3";
    // ERC1155: cannot transfer or mint to the zero address     铸币或转移时to地址不能为空
    string constant To_Empty_Address = "\xE9\x93\xB8\xE5\xB8\x81\xE6\x88\x96\xE8\xBD\xAC\xE7\xA7\xBB\xE6\x97\xB6\x74\x6F\xE5\x9C\xB0\xE5\x9D\x80\xE4\xB8\x8D\xE8\x83\xBD\xE4\xB8\xBA\xE7\xA9\xBA";
    // ERC1155: burn from the zero address      销毁时from地址不能为空
    string constant From_Empty_Address = "\xE9\x94\x80\xE6\xAF\x81\xE6\x97\xB6\x66\x72\x6F\x6D\xE5\x9C\xB0\xE5\x9D\x80\xE4\xB8\x8D\xE8\x83\xBD\xE4\xB8\xBA\xE7\xA9\xBA";
    // ERC1155: burn amount exceeds balance     销毁数量超过可用数量
    string constant Exceeds_Balance = "\xE9\x94\x80\xE6\xAF\x81\xE6\x95\xB0\xE9\x87\x8F\xE8\xB6\x85\xE8\xBF\x87\xE5\x8F\xAF\xE7\x94\xA8\xE6\x95\xB0\xE9\x87\x8F";
    // ERC1155: args array length mismatch      数组参数长度不匹配
    string constant Lenght_Mismatch = "\xE6\x95\xB0\xE7\xBB\x84\xE5\x8F\x82\xE6\x95\xB0\xE9\x95\xBF\xE5\xBA\xA6\xE4\xB8\x8D\xE5\x8C\xB9\xE9\x85\x8D";
    // ERC1155: setting approval status for self        授权给自己没有意义
    string constant Approval_To_Self = "\xE6\x8E\x88\xE6\x9D\x83\xE7\xBB\x99\xE8\x87\xAA\xE5\xB7\xB1\xE6\xB2\xA1\xE6\x9C\x89\xE6\x84\x8F\xE4\xB9\x89";
    // ERC1155: balance query for the zero address      查询地址不能为空
    string constant Query_Empty_Address = "\xE6\x9F\xA5\xE8\xAF\xA2\xE5\x9C\xB0\xE5\x9D\x80\xE4\xB8\x8D\xE8\x83\xBD\xE4\xB8\xBA\xE7\xA9\xBA";
    // ERC1155: insufficient balance for transfer       可用代币数量不足
    string constant Insufficient_Balance = "\xE5\x8F\xAF\xE7\x94\xA8\xE4\xBB\xA3\xE5\xB8\x81\xE6\x95\xB0\xE9\x87\x8F\xE4\xB8\x8D\xE8\xB6\xB3";
    // uri cannot be empty      uri不能为空
    string constant Empty_URI = "\x75\x72\x69\xE4\xB8\x8D\xE8\x83\xBD\xE4\xB8\xBA\xE7\xA9\xBA";
    // ERC1155: ERC1155Receiver rejected tokens     ERC1155Receiver拒绝接受代币
    string constant Rejected_Tokens = "\x45\x52\x43\x31\x31\x35\x35\x52\x65\x63\x65\x69\x76\x65\x72\xE6\x8B\x92\xE7\xBB\x9D\xE6\x8E\xA5\xE5\x8F\x97\xE4\xBB\xA3\xE5\xB8\x81";
    // ERC1155: transfer to non ERC1155Receiver implementer     未实现ERC1155Receiver接口
    string constant Interface_Not_Implement = "\xE6\x9C\xAA\xE5\xAE\x9E\xE7\x8E\xB0\x45\x52\x43\x31\x31\x35\x35\x52\x65\x63\x65\x69\x76\x65\x72\xE6\x8E\xA5\xE5\x8F\xA3";


    // 初始化构造方法
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // ------- 转移、销毁权限校验 -------
    modifier txOrBurnPermission(address from, uint256 tokenId) {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()) || howManyApproved(from, _msgSender(), tokenId) > 0,
            Permission_Insufficient
        );
        _;
    }

    // ------- to空地址校验 -------
    modifier toEmptyAddressCheck(address to) {
        require(to != address(0), To_Empty_Address);
        _;
    }

    // ------- 两个切片参数长度校验 -------
    modifier lengthCheck(uint256 aLength, uint256 bLength) {
        require(aLength == bLength, Lenght_Mismatch);
        _;
    }

    // 支持IERC1155/IERC1155MetadataURI/IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId); // super来自erc165，会判断是否支持165接口
    }

    // IERC1155MetadataURI
    function uri(uint256 id) public view virtual override returns (string memory) {
        return idToUri[id];
    }

    // 获取代币名
    function getName() external view returns (string memory) {
        return _name;
    }

    // 获取代币符号
    function getSymbol() external view returns (string memory) {
        return _symbol;
    }

    // 查询地址不能为空
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), Query_Empty_Address);
        return _balances[id][account];
    }

    // account跟ids参数长度必须一致
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        lengthCheck(accounts.length, ids.length)
        returns (uint256[] memory) 
    {
        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    // IERC1155规定的方法
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    // 部分授权
    function setApprovalForPart(address operator, uint256 tokenId, uint256 amount) external {
        _setApprovalForPart(_msgSender(), operator, tokenId, amount);
    } 

    // IERC1155规定的方法
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    // 查询a账户对o账户授权tokenId代币的可用数量
    function howManyApproved(address account, address operator, uint256 tokenId) public view returns (uint256) {
        return _approvalCounts[account][operator][tokenId];
    }

    // IERC1155规定的方法，代币转移
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override txOrBurnPermission(from, id) {
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * IERC1155规定的方法, 
     * 与单个转移不同, 这里无法校验授权数量
     * 已经放到_before校验, 所以注释掉require
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        // require(
        //     from == _msgSender() || isApprovedForAll(from, _msgSender()),
        //     "ERC1155: transfer caller is not owner nor approved"
        // );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    // 转移到合约地址时，该合约需要实现IERC1155Receiver-onERC1155Received接口
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual toEmptyAddressCheck(to) {

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, Insufficient_Balance);
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual lengthCheck(ids.length, amounts.length) toEmptyAddressCheck(to){

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, Insufficient_Balance);
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    // 重复id直接覆盖旧的uri
    function _setURI(uint256 id, string memory newuri) internal virtual {
        require(bytes(newuri).length > 0, Empty_URI);
        idToUri[id] = newuri;
    }

    // 铸币to地址不能为空；此外，如果to是个合约地址，该合约必须实现IERC1155Receiver-onERC1155Received接口
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        string calldata _uri,
        bytes memory data
    ) external mintPermissionVerified toEmptyAddressCheck(to) {

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        // 设置uri
        _setURI(id, _uri);
        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    // 批量铸币
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        string[] calldata uris,
        bytes memory data
    ) external
    mintPermissionVerified
    toEmptyAddressCheck(to)
    lengthCheck(ids.length, amounts.length)
    lengthCheck(ids.length, uris.length)
    {

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            _setURI(ids[i], uris[i]);
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    // 销毁
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external virtual txOrBurnPermission(from, id) {
        require(from != address(0), From_Empty_Address);

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, Exceeds_Balance);
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    // 批量销毁
    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external virtual lengthCheck(ids.length, amounts.length) {
        require(from != address(0), From_Empty_Address);

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, Exceeds_Balance);
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    // 授权owner账户下所有代币的权限给operator，权限为T时operator可以任意处理owner账户下的代币
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, Approval_To_Self);
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    // 授权部分代币数量
    function _setApprovalForPart(
        address owner,
        address operator,
        uint256 tokenId,
        uint256 amount
    ) internal virtual {
        require(owner != operator, Approval_To_Self);
        require(_balances[tokenId][owner] >= amount , Insufficient_Balance);
        _approvalCounts[owner][operator][tokenId] = amount;
    }

    /** 
     * 关于from与to只有下列三种情况:
     *
     * from与to均非空地址时表示转账
     * from空地址, to非空表示铸币
     * to空地址, from非空表示销毁
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (from != address(0)) {
            // 转账或销毁时, 如果不是完全授权
            if (!isApprovedForAll(from, operator)) {
                for (uint256 i = 0; i < ids.length; i++) {
                    // Approved amount insufficient 授权数量不足
                    require(howManyApproved(from, operator, ids[i]) >= amounts[i], Permission_Insufficient);
                }
            } else if (_msgSender() == from || isApprovedForAll(from, operator)) {
                // 正常
            } else {
                // ERC1155: transfer caller is not owner nor approved
                revert(Permission_Insufficient);
            }
        } else if (to == address(0) || data.length == 0) {
            // 没有意义，只是为了消掉警告
        }
    }

    /// @param to: 对铸币暂时没有额外限制
    /// @param data: 接口需要, 暂时用不上
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (from != address(0)) {
            if (!isApprovedForAll(from, operator)) {
                for (uint256 i = 0; i < ids.length; i++) {
                    // 授权可用数量减少，0.8版本的solidity内置safeMath，uint(0)-正数时自动回退
                    _approvalCounts[from][operator][ids[i]] -= amounts[i];
                }
            }
        } else if (to == address(0) || data.length == 0) {
            // make no sense
        }
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert(Rejected_Tokens);
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert(Interface_Not_Implement);
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert(Rejected_Tokens);
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert(Interface_Not_Implement);
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
