# Token1155



### 基于OpenZeppelin实现的ERC1155代币



### 特色：

**授权机制**

​	增加部分授权，持有代币的用户可以只授权指定代币id的若干数量给另一个用户

**权限控制**

​	增加开关，合约持有人可以启用或关闭权限控制（只对**铸币**行为生效）



### 方法：

#### ACL相关：

**enableACL**(bool)

​	启用或关闭铸币的权限控制（**默认启用**），只有合约持有者**owner()**可以调用。



**addPermission**(address)

​	给address用户**增加铸币权限**



**removePermission**(address)

​	**移除**address用户的**铸币权限**



**ifHasPermission**(address)

​	查询address**是否有铸币权限**



#### 代币铸造与销毁

**mint**(to, id, amount, _uri, data)

​	**铸币**。为to地址铸造amount个唯一识别码为id的代币，这些代币的uri都是_uri

​	如果mint时id已经存在，则增发

​	data传`[]`即可，目前data参数用不上



**mintBatch**(to, ids[], amount[], _uri, data)

​	**批量铸币**。与mint基本相同，只是同时铸造多种代币而已



**burn**(from, id, amount)

​	**销毁代币**。销毁from账号下amount个数量的id代币

​	burn可销毁非自己账号下的代币，前提是需要其它账户授权给自己使用（部分授权下销毁量不能超过被授权的数量）



**burnBatch**(from, ids[], amount[])

​	**批量销毁代币**。与burn基本相同



#### 转账相关

**safeTransferFrom**(from, to, id, amount, data)

​	**转移代币**。转移from账号下amount个id代币到to账号下

​	与burn同理，可以转移非自己账号下的代币到to账号，只需要被授权

​	data同样传`[]`，目前用不上这个参数



**safeBatchTransferFrom**(from, to, ids[], amounts[], data)

​	**批量转移代币**。与safeTransferFrom基本相同



#### 授权相关

**setApprovalForAll**(operator, bool)

​	**完全授权**。交易发起人(A)授权operator账号，bool为T时，operator账号可以任意转移或销毁A账号下的任意代币任意数量



**setApprovalForPart**(operator, tokenId, amount)

​	**部分授权**。对完全授权做了一些限制，只授权amount个tokenId的使用权给operator



**isApprovedForAll**(account, operator)

​	查询operator是否被account完全授权



**howManyApproved**(account, operator, tokenId)

​	查询account授权给operator用户tokenId代币多少个使用权



#### 其它

**owner**()

​	查询合约持有者



**uri**(tokenId)

​	查询代币id到uri的映射



**getName**()

​	查询主合约代币名



**getSymbol**()

​	查询主合约代币符号



**balanceOf**(account, id)

​	查询account账号下有多少个id代币



**balanceOfBatch**(account[], ids[])

​	批量查询多个账号下的代币数量。与balanceOf基本相同

**supportsInterface**(bytes4[])

​	查询本合约是否支持参数的接口。

​	目前支持的接口(IERC1155/IERC1155MetadataURI/IERC165)

