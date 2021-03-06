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
    // 对本合约发行的fungible-token通用元数据地址,客户端解析时需要将代币id与此uri结合
    // 例如: https://token/{id}.json, 解析: strings.Replace(_uri, "{id}", string(tokenId))
    string private _uri;
    // nft记录
    mapping(uint256 => bool) private _exists;

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
    // nft-id exists    nft-id已经存在
    string constant NFT_Exists = "\x6E\x66\x74\x2D\x69\x64\xE5\xB7\xB2\xE7\xBB\x8F\xE5\xAD\x98\xE5\x9C\xA8";


    // 初始化构造方法
    constructor(string memory uri_) {
        _setURI(uri_);
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

    // 判断一个id是否为nft，规定最高位为1时为nft
    function isNFT(uint256 id) internal pure returns (bool) {
        if (id & uint256(0x8000000000000000000000000000000000000000000000000000000000000000) == 0) {
            // 最高位为0 is fungible token
            return false;
        }else {
            // none-fungible token
            return true;
        }
    }

    // 支持IERC1155/IERC1155MetadataURI/IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId); // super来自erc165，会判断是否支持165接口
    }

    // IERC1155MetadataURI---Clients calling this function must replace the `\{id\}` substring with the actual token type ID.
    function uri(uint256 id) public view virtual override returns (string memory) {
        // isNFT(id);
        id;
        return _uri;
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
    ) public virtual override {
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

        // emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     */ 
    function _setURI(string memory newuri) internal virtual {
        // 不允许uri为空
        require(bytes(newuri).length > 0, Empty_URI);
        _uri = newuri;
    }

    // 铸币to地址不能为空；此外，如果to是个合约地址，该合约必须实现IERC1155Receiver-onERC1155Received接口
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external mintPermissionVerified toEmptyAddressCheck(to) {

        // nft 数量只能为1，且未发行过
        if (isNFT(id)) {
            require(amount == 1 && !_exists[id], NFT_Exists);
            // 标识存在
            _exists[id] = true;
        }

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

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
        bytes memory data
    ) external
    mintPermissionVerified
    toEmptyAddressCheck(to)
    lengthCheck(ids.length, amounts.length)
    {

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            if (isNFT(ids[i])) {
                require(amounts[i] == 1 && !_exists[ids[i]], NFT_Exists);
                _exists[ids[i]] = true;
            }
            _balances[ids[i]][to] += amounts[i];
        }

        // emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    // 销毁
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external virtual {
        require(from != address(0), From_Empty_Address);

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, Exceeds_Balance);
        unchecked {
            _balances[id][from] = fromBalance - amount;
            // 如果是销毁nft 置为false
            if (isNFT(id)) {
                _exists[id] = false;
            }
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
                if (isNFT(id)) {
                    _exists[id] = false;
                }
            }
        }

        // emit TransferBatch(operator, from, address(0), ids, amounts);

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
            // 转账或销毁时, 如果是代币持有者或完全授权
            if (operator == from || isApprovedForAll(from, operator)) {
                // 正常
            } else {
                for (uint256 i = 0; i < ids.length; i++) {
                    // Approved amount insufficient 授权数量不足
                    require(howManyApproved(from, operator, ids[i]) >= amounts[i], Permission_Insufficient);
                }
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
            if (operator == from || isApprovedForAll(from, operator)) {
                // 正常
            } else {
                for (uint256 i = 0; i < ids.length; i++) {
                    // 授权可用数量减少，0.8版本的solidity内置safeMath，uint(0)-正数时自动回退，但是没有错误提示!
                    require(_approvalCounts[from][operator][ids[i]] >= amounts[i], Permission_Insufficient);
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
