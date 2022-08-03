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
    // 代币id ==> 代币uri
    mapping(uint256 => string) private uriMap;
    // 原持有人地址 ==> (授权地址 --> 授权状态T/F)
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // 授权部分数量
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _approvalCounts;
    // 对本合约发行的fungible-token通用元数据地址,客户端解析时需要将代币id与此uri结合
    // 例如: https://token/{id}.json, 解析: strings.Replace(_uri, "{id}", string(tokenId))
    string private _baseuri;
    // nft记录
    // mapping(uint256 => bool) private _exists;

    // ------- 错误信息 -------
    // 
    // 交易发起人不是代币持有者或被授权的可使用数量不足
    string constant Permission_Insufficient = "Caller is not owner or approved amount insufficient";
    // 铸币或转移时to地址不能为空
    string constant To_Empty_Address = "Cannot transfer or mint to the zero address";
    // 销毁时from地址不能为空
    string constant From_Empty_Address = "Burn from the zero address";
    // 销毁数量超过可用数量
    string constant Exceeds_Balance = "Burn amount exceeds balance";
    // 数组参数长度不匹配
    string constant Lengths_Mismatch = "Args array length mismatch";
    // 授权给自己没有意义
    string constant Approval_To_Self = "Setting approval status for self make no sence";
    // 查询地址不能为空
    string constant Query_Empty_Address = "Balance query for the zero address";
    // 可用代币数量不足
    string constant Insufficient_Balance = "Insufficient balance for transfer";
    // uri不能为空
    string constant Empty_URI = "URI cannot be empty";
    // ERC1155Receiver拒绝接受代币
    string constant Rejected_Tokens = "ERC1155Receiver rejected tokens";
    // 未实现ERC1155Receiver接口
    string constant Interface_Not_Implement = "Transfer to non ERC1155Receiver implementer";
    // nft-id已经存在
    // string constant NFT_Exists = "nft-id exists";
    // 该代币id已经存在
    string constant Token_Exists = "The token id already exists";
    // 该代币id不存在
    string constant Token_Not_Exists = "The token id does not exist";
    // 当to长度为1时amounts长度也应为1
    string constant Amounts_To_Length_Mismatch_When_To_One = "amounts'length should be the same with to's length when to.length equal 1";
    // amounts长度应与to长度一致
    string constant Amounts_To_Length_Mismatch = "amounts'length should be the same with to's length";


    // 初始化构造方法 只设置owner
    constructor(address owner) AccessControl(owner) {
        _setURI("");
    }

    // ------- to空地址校验 -------
    modifier toEmptyAddressCheck(address to) {
        require(to != address(0), To_Empty_Address);
        _;
    }

    // ------- 两个切片参数长度校验 -------
    modifier lengthCheck(uint256 aLength, uint256 bLength) {
        require(aLength == bLength, Lengths_Mismatch);
        _;
    }

    // ------
    // 代币转移权限校验
    // 写在_beforeTokenTransfer()中
    // 因为isApprovedForAll与howManyApproved两个不能同时校验 强行写在一个modify中很麻烦
    // 虽然目前也没有部分授权的需求 但是指不定后续就有这样的要求了
    // ------

    // deprecate 判断一个id是否为nft，规定最高位为1时为nft
    // function isNFT(uint256 id) internal pure returns (bool) {
    //     if (id & uint256(0x8000000000000000000000000000000000000000000000000000000000000000) == 0) {
    //         // 最高位为0 is fungible token
    //         return false;
    //     }else {
    //         // none-fungible token
    //         return true;
    //     }
    // }

    // 支持IERC1155/IERC1155MetadataURI/IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId); // super来自erc165，会判断是否支持165接口
    }

    // IERC1155MetadataURI---查询某个代币类别的uri Clients calling this function must replace the `\{id\}` substring with the actual token type ID.
    function uri(uint256 id) public view virtual override returns (string memory) {
        // isNFT(id); 
        return uriMap[id];
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
        // require(bytes(newuri).length > 0, Empty_URI);
        _baseuri = newuri;
    }

    // --- demand start 配合新需求专门增加的方法 ---
    // owner单独修改某个代币类别的uri
    function reviseURI(uint256 id, string calldata newuri) external onlyOwner {
        require(bytes(newuri).length > 0, Empty_URI);
        require(bytes(uriMap[id]).length > 0, Token_Not_Exists);
        uriMap[id] = newuri;
    }

    // 铸币同时设置uri 校验代币是否存在 如果已经存在只能调用增发方法
    function mintExtension(
        address[] calldata to, // 可以同时给多个地址铸币
        uint256 id,
        uint256[] calldata amounts, // 每个地址数量收到的代币可以不同
        string calldata tokenUri,
        bytes memory data
    ) external {
        // 不使用baseUri而是为每种代币单独设置uri情况下 需要该uri非空
        require(bytes(tokenUri).length > 0, Empty_URI);
        // 为了避免增发时覆盖掉同种类代币的uri 已经存在的代币种类无法使用此方法铸造 调用mintExist方法(因为该方法不传uri参数)即可
        require(bytes(uriMap[id]).length == 0, Token_Exists);

        if (to.length == 1) {
            require(amounts.length == 1, Amounts_To_Length_Mismatch_When_To_One);
            mint(to[0], id, amounts[0], data);
        } else {
            if (amounts.length == 1) {
                // 每一个地址都得到同样数量的代币
                for (uint256 i = 0; i < to.length; i++) {
                    mint(to[i], id, amounts[0], data);
                }
            } else {
                // 每个地址得到的代币数量不同
                require(to.length == amounts.length, Amounts_To_Length_Mismatch);
                for (uint256 i = 0; i < to.length; i++) {
                    mint(to[i], id, amounts[i], data);
                }
            }
        }

        // uriMap增加键值对
        uriMap[id] = tokenUri;
    }
    
    // 增发代币
    function mintExist(
        address[] calldata to,
        uint256 id,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        // 增发代币需要保证该代币已铸造过
        require(bytes(uriMap[id]).length > 0, Token_Not_Exists);

        // 跟mintExtension方法基本一致
        if (to.length == 1) {
            require(amounts.length == 1, Amounts_To_Length_Mismatch_When_To_One);
            mint(to[0], id, amounts[0], data);
        } else {
            if (amounts.length == 1) {
                // 每一个地址都得到同样数量的代币
                for (uint256 i = 0; i < to.length; i++) {
                    mint(to[i], id, amounts[0], data);
                }
            } else {
                // 每个地址得到的代币数量不同
                require(to.length == amounts.length, Amounts_To_Length_Mismatch);
                for (uint256 i = 0; i < to.length; i++) {
                    mint(to[i], id, amounts[i], data);
                }
            }
        }
    }
    // --- demand end ---

    // 铸币to地址不能为空；此外，如果to是个合约地址，该合约必须实现IERC1155Receiver-onERC1155Received接口
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal mintPermissionVerified toEmptyAddressCheck(to) {

        // nft 数量只能为1，且未发行过
        // if (isNFT(id)) {
        //     require(amount == 1 && !_exists[id], NFT_Exists);
        //     // 标识存在
        //     _exists[id] = true;
        // }

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
            // if (isNFT(ids[i])) {
            //     require(amounts[i] == 1 && !_exists[ids[i]], NFT_Exists);
            //     _exists[ids[i]] = true;
            // }
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
            // if (isNFT(id)) {
            //     _exists[id] = false;
            // }
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
                // if (isNFT(id)) {
                //     _exists[id] = false;
                // }
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
            if (operator == from || isApprovedForAll(from, operator) || operator == owner()) {
                // 正常 新增: owner可以转移/销毁任意代币
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
