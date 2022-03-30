# Token1155

## 基于OpenZeppelin实现的ERC1155代币

### 更新信息

为兼容xchain，对于批量操作（批量铸币、转移、销毁）取消emit事件

通过代币id信息，明确区别fungible token与none-fungible token，规定**uint256**的id最高位为1时代币为nft，数量限制最多为1

### 合约编译

```shell
git clone https://github.com/vantinfy/Token1155.git
cd Token1155

# 编译 需要确保有sloc编译器
sloc --bin --abi Token1155.sol -o output
# 编译后在output目录下的Token1155.bin跟Token1155.abi就是所需要的文件了
```

### 部署调用

```shell
# xchain run
git clone https://github.com/superconsensus/matrixchain.git
cd matrixchain
make
make testnet
cd testnet/node1
# 注意：如果是本地测试，需要先注释掉node1、2、3下的conf/network.yaml的第15、16、17行，取消注释18、19、20行
bash control.sh start
cd ../node2
bash control.sh start
cd ../node3
bash contol.sh start
# 到这里三个节点启动完毕

# 使用node1创建合约账号
./bin/xchain-cli account new --account 1111111111111111 --fee 1000
./bin/xchain-cli transfer --to XC1111111111111111@matrixchain --amount 100000000 --fee 1000000
# deploy（多文件还不支持通过xupercc部署）部署消耗24386UTXO左右，output为编译生成的文件夹
./bin/xchain-cli evm deploy --abi ./output/Token1155.abi --cname t1155 --account XC1111111111111111@matrixchain ./output/Token1155.bin -a '{"uri_":"https://token/{id}.json"}' --fee 24386

# evm合约有些操作需要用到eth地址，需要先做地址转换（离线操作，不需要gas）
./bin/xchain-cli evm addr-trans -f `cat keys/address` -t x2e
# result, AAC3DE59023AC0EE081D62BE60CA6674FDCAE759  xchain

# 调用方式1 终端命令行。注意：部分需要通过合约账号发起的交易，invoke时加上"--account XC...@chainName"即可
./bin/xchain-cli evm invoke ${contractName} --method ${methodName} -a '{"arg1": "value"}' --fee 0
./bin/xchain-cli evm query ${contractName} --method ${methodName} -a '{"arg1": "value"}' --fee 0

# 调用方式2 通过xupercc
git clone https://github.com/superconsensus-chain/xupercc.git
cd xupercc
chmod +x xdev/solc xdev/xdev
go build
# 默认运行在8080端口，可通过conf/app.ini的http_port字段修改
./xupercc # 后台运行 nohup ./xupercc &
# 使用http请求工具例如postman即可
```

### 特色

#### 授权机制

增加部分授权，持有代币的用户可以只授权指定代币id的若干数量给另一个用户

#### 权限控制

增加开关，合约持有人可以启用或关闭权限控制（只对**铸币**行为生效）

### API

#### ACL相关

接口统一调用地址(xupercc方式下): <http://192.168.3.6:8080/v1/contract_invoke> （ip与端口自行修改）

**enableACL**(bool)

启用或关闭铸币的权限控制（**默认启用**），此方法只有合约持有者**(可以通过owner()查询)**可以调用。

请求参数

| 参数名 | 参数类型         | 参数说明      | 是否消耗gas |
| ------ | ---------------- | ------------- | ----------- |
| enable | 字符串类型的bool | 启用或关闭ACL | 是          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name": "t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"enableACL",
    "args":{
        "enable": "true"
    },
    "query": false
}
```

响应示例

```shell
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "685e0f1a70fc3e013e78676963039ca841602b304d912af2d88b3c049d8020e6",
        "data": "[]",
        "gas_used": 65
    }
}
```

**addPermission**(address)

给address用户**增加铸币权限**

请求参数

| 参数名  | 参数类型      | 参数说明                  | 是否消耗gas |
| ------- | ------------- | ------------------------- | ----------- |
| account | address字符串 | 为account地址增加铸币权限 | 是          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"addPermission",
    "args":{
        "account": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759"
    },
    "query": false
}
```

响应示例

```json
// 错误情况1 参数account的格式不符合eth Address规范。解决方式：使用x-client evm addr-trans ...转换后再传参
{
    "code": 400,
    "error": "PreExecWithSelectUTXO failed: rpc error: code = Unknown desc = Err:500-50501-contract invoke failed+could not convert 'true' to address: go-hex: invalid byte: U+0074 't'",
    "msg": "操作失败"
}
// 错误情况2 此方法只有合约持有者能调用。解决方法：由合约部署者发起即可（传contract_account参数，填合约部署时的合约账号）
{
    "code": 400,
    "error": "PreExecWithSelectUTXO failed: rpc error: code = Unknown desc = Err:500-50501-contract invoke failed+error 17 - Error 17: execution reverted: with reason 'Ownable: caller is not the owner'",
    "msg": "操作失败"
}
// 成功情况
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "a825b18650c9b8ecc35175c065f16bd419fa0e7b099a7599cc3450308d949a5c",
        "data": "[]",
        "gas_used": 129
    }
}
```

**removePermission**(address)

**移除**address用户的**铸币权限**

参数

| 参数名  | 参数类型      | 参数说明                  | 是否消耗gas |
| ------- | ------------- | ------------------------- | ----------- |
| account | address字符串 | 移除account地址的铸币权限 | 是          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"removePermission",
    "args":{
        "account": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759"
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "80d52d6ef2dae210d16a9609f15e9e56285abdebbbd1b12b1769ca39af39a96d",
        "data": "[]",
        "gas_used": 129
    }
}
```

**ifHasPermission**(address)

查询address**是否有铸币权限**

| 参数名  | 参数类型      | 参数说明                      | 是否消耗gas |
| ------- | ------------- | ----------------------------- | ----------- |
| account | address字符串 | 查询account地址是否有铸币权限 | 否          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"ifHasPermission",
    "args":{
        "account": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"true\"}]"
    }
}
```

#### 代币铸造与销毁

**mint**(to, id, amount, _uri, data)

**铸币**。为to地址铸造amount个唯一识别码为id的代币，这些代币的uri都是_uri

如果mint时id已经存在，则增发

data传`"[]"`或`""`即可，目前data参数用不上

请求参数

| 参数名 | 参数类型      | 参数说明                           | 是否消耗gas |
| ------ | ------------- | ---------------------------------- | ----------- |
| to     | address字符串 | 铸币到to地址下                     | 是          |
| id     | uint256字符串 | 代币id，如与已有代币id相同视为增发 |             |
| amount | uint256字符串 | 铸造数量                           |             |
| data   | bytes字符串   | 后续拓展使用                       |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"mint",
    "args":{
        "to": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "id": "123",
        "amount": "1000",
        "data": ""
    },
    "query": false
}
```

响应示例

```json
// 成功情况
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "727a9c53e7a2a336fb6c3869c814e2b8353e52ac7c468ab0b4809b40a082ecca",
        "data": "[]",
        "gas_used": 288
    }
}
// 可能的失败情况(未被授予铸币权限)
{
    "code": 400,
    "error": "PreExecWithSelectUTXO failed: rpc error: code = Unknown desc = Err:500-50501-contract invoke failed+error 17 - Error 17: execution reverted: with reason 'Insufficient permissions for mint'",
    "msg": "调用失败"
}
```

**mintBatch**(to, ids[], amount[], _uri, data)

**批量铸币**。与mint基本相同，只是同时铸造多种代币(可以重复同一种)而已

| 参数名  | 参数类型        | 参数说明             | 是否消耗gas |
| ------- | --------------- | -------------------- | ----------- |
| to      | address字符串   | 铸币到to地址下       | 是          |
| ids     | uint256[]字符串 | 每种代币id           |             |
| amounts | uint256[]字符串 | 各id代币对应铸造数量 |             |
| data    | bytes[]字符串   | 后续拓展使用         |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"mintBatch",
    "args":{
         "to": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "ids": "[123,1234]",
        "amounts": "[1000,4000]",
        "data": ""
    },
    "query":false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "74e8388884c9bd972cd68d77b1d3150bf0256d3506afbe7a49183540a780ecdb",
        "data": "[]",
        "gas_used": 195
    }
}
```

**burn**(from, id, amount)

**销毁代币**。销毁from账号下amount个数量的id代币

burn可销毁非自己账号下的代币，前提是需要其它账户授权给自己使用（部分授权下销毁量不能超过被授权的数量）

| 参数名 | 参数类型      | 参数说明             | 是否消耗gas |
| ------ | ------------- | -------------------- | ----------- |
| from   | address字符串 | 销毁from账号下的代币 | 是          |
| id     | uint256字符串 | 要销毁的代币id       |             |
| amount | uint256字符串 | 要销毁的数量         |             |

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"burn",
    "args":{
        "from": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "id": "123",
        "amount": "7"
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "0648125900b2589ba202dde704f3ae20467a4d9697bb769f228a8e69a0ad99ba",
        "data": "[]",
        "gas_used": 223
    }
}
```

**burnBatch**(from, ids[], amount[])

**批量销毁代币**。与burn基本相同

| 参数名  | 参数类型        | 参数说明                     | 是否消耗gas |
| ------- | --------------- | ---------------------------- | ----------- |
| from    | address字符串   | 销毁from账号下的多种代币若干 | 是          |
| ids     | uint256[]字符串 | 要销毁代币种类               |             |
| amounts | uint256[]字符串 | 每种代币要销毁的数量         |             |

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"burnBatch",
    "args":{
        "from": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "ids": "[123,1234]",
        "amounts": "[10,10]"
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "efe9ac1e89f5387de538230846e3f77f7493c813e7bf4e79fa110cab8551f06f",
        "data": "[]",
        "gas_used": 130
    }
}
```

#### 转账相关

**safeTransferFrom**(from, to, id, amount, data)

**转移代币**。转移from账号下amount个id代币到to账号下

与burn同理，可以转移非自己账号下的代币到to账号，只需要被授权

data同样传`[]`，目前用不上这个参数

| 参数名 | 参数类型      | 参数说明             | 是否消耗gas |
| ------ | ------------- | -------------------- | ----------- |
| from   | address字符串 | 从from账号下转移代币 | 是          |
| to     | address字符串 | 转移代币到to账号     |             |
| id     | uint256字符串 | 要转移的代币id       |             |
| amount | uint256字符串 | 要转移的代币数量     |             |
| data   | bytes字符串   | 后续拓展使用         |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"safeTransferFrom",
    "args":{
        "from": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "to": "49D078F385DF780A3AFDE32EF437AF54B1732D4C",
        "id": "123",
        "amount": "2",
        "data": ""
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "65e8317b4a1b7c1dc73ccb57470bd4d61cc6bafe8cc20b27d4a1c5532a7bca4b",
        "data": "[]",
        "gas_used": 287
    }
}
```

**safeBatchTransferFrom**(from, to, ids[], amounts[], data)

**批量转移代币**。与safeTransferFrom基本相同

| 参数名  | 参数类型        | 参数说明                       | 是否消耗gas |
| ------- | --------------- | ------------------------------ | ----------- |
| from    | address字符串   | 从from账号下转移多种代币各若干 | 是          |
| to      | address字符串   | 转移代币到to账号               |             |
| ids     | uint256[]字符串 | 要转移的代币种类               |             |
| amounts | uint256[]字符串 | 各种类代币要转移的数量         |             |
| data    | bytes字符串     | 后续拓展使用                   |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"safeBatchTransferFrom",
    "args":{
        "from": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "to": "49D078F385DF780A3AFDE32EF437AF54B1732D4C",
        "ids": "[123]",
        "amounts": "[10]",
        "data": ""
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "c9d54474e3f581bcfa5e7c80ad4c6332ad992344f548fde381c78d7577533a7c",
        "data": "[]",
        "gas_used": 131
    }
}
```

#### 授权相关

**setApprovalForAll**(operator, bool)

**完全授权**。交易发起人(A)授权operator账号，bool为T时，operator账号可以任意转移或销毁A账号下的任意代币任意数量

| 参数名   | 参数类型      | 参数说明                             | 是否消耗gas |
| -------- | ------------- | ------------------------------------ | ----------- |
| operator | address字符串 | 授权操作者                           | 是          |
| approved | bool字符串    | 该操作者是否可以任意使用发起人的代币 |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "resemble silk fun hamster dress tobacco boss art borrow erode donor idle benefit shoe empty story staff mammal",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"setApprovalForAll",
    "args":{
        "operator": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "approved": "true"
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "580bac91322921b6433cb161d032ba42076fb97a80f021630f3f0379f97551dd",
        "data": "[]",
        "gas_used": 176
    }
}
```

**setApprovalForPart**(operator, tokenId, amount)

**部分授权**。对完全授权做了一些限制，只授权amount个tokenId的使用权给operator

| 参数名   | 参数类型      | 参数说明                                                | 是否消耗gas |
| -------- | ------------- | ------------------------------------------------------- | ----------- |
| operator | address字符串 | 授权操作者                                              | 是          |
| tokenId  | uint256字符串 | 该操作者可以任意使用发起人账号下代币tokenId             |             |
| amount   | uint256字符串 | 可以使用的代币数量（如需取消已授权数量，将此值置0即可） |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"setApprovalForPart",
    "args":{
        "operator": "49D078F385DF780A3AFDE32EF437AF54B1732D4C",
        "tokenId": "123",
        "amount": "10"
    },
    "query": false
}
```

响应示例

```json
{
    "code": 200,
    "msg": "调用成功",
    "resp": {
        "txid": "46d6dbd039811a722300a375257d388736c747ddb3281123c6e1a2df9a542841",
        "data": "[]",
        "gas_used": 129
    }
}
```

**isApprovedForAll**(account, operator)

查询operator是否被account完全授权

| 参数名   | 参数类型      | 参数说明     | 是否消耗gas |
| -------- | ------------- | ------------ | ----------- |
| account  | address字符串 | 原代币持有者 | 否          |
| operator | address字符串 | 被授权人     |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "contract_account": "XC1111111111111111@matrixchain",
    "module_name": "evm",
    "method_name":"isApprovedForAll",
    "args":{
        "account": "49D078F385DF780A3AFDE32EF437AF54B1732D4C",
        "operator": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"true\"}]"
    }
}
```

**howManyApproved**(account, operator, tokenId)

查询account授权给operator用户tokenId代币多少个使用权

| 参数名   | 参数类型      | 参数说明     | 是否消耗gas |
| -------- | ------------- | ------------ | ----------- |
| account  | address字符串 | 原代币持有者 | 否          |
| operator | address字符串 | 被授权人     |             |
| tokenId  | uint256字符串 | 授权何种代币 |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"howManyApproved",
    "args":{
        "account": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "operator": "49D078F385DF780A3AFDE32EF437AF54B1732D4C",
        "tokenId": "123"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"10\"}]"
    }
}
```

#### 其它

**owner**()

查询合约持有者

| 参数名     | 参数类型 | 参数说明 | 是否消耗gas |
| ---------- | -------- | -------- | ----------- |
| 不需要参数 | -        | -        | 否          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"owner",
    "query": true
}
```

响应示例

```json
// 合约账号只是对XC与@之间的16个数字进行转换而已
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"3131313231313131313131313131313131313131\"}]"
    }
}
```

**uri**(tokenId)

查询代币id到uri的映射

请求参数

| 参数名 | 参数类型      | 参数说明                                                     | 是否消耗gas |
| ------ | ------------- | ------------------------------------------------------------ | ----------- |
| id     | uint256字符串 | 接口规定代币id（注意返回uri为通用模板，需要客户端进一步处理） | 否          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"uri",
    "args": {
        "id": "1"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"https://haha/{id}.json\"}]"
    }
}
```

**balanceOf**(account, id)

查询account账号下有多少个id代币

| 参数名  | 参数类型      | 参数说明                  | 是否消耗gas |
| ------- | ------------- | ------------------------- | ----------- |
| account | address字符串 | 查询account账户           | 否          |
| id      | uint256字符串 | 查询account账户下的代币id |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"balanceOf",
    "args":{
        "account": "AAC3DE59023AC0EE081D62BE60CA6674FDCAE759",
        "id": "123"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"1000\"}]"
    }
}
```

**balanceOfBatch**(account[], ids[])

批量查询多个账号下的代币数量。与balanceOf基本相同

| 参数名   | 参数类型        | 参数说明                       | 是否消耗gas |
| -------- | --------------- | ------------------------------ | ----------- |
| accounts | address[]字符串 | 要查询的多个目标账户           | 否          |
| ids      | uint256[]字符串 | 要查询的各个账户下对应的代币id |             |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"balanceOfBatch",
    "args":{
        "accounts": "[AAC3DE59023AC0EE081D62BE60CA6674FDCAE759,AAC3DE59023AC0EE081D62BE60CA6674FDCAE759]",
        "ids": "[123,124]"
    },
    "query": true
}
```

响应示例

```json
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"[1000,0]\"}]"
    }
}
```

**supportsInterface**(bytes4[])

查询本合约是否支持参数的接口。

目前支持的接口(IERC1155/IERC1155MetadataURI/IERC165)

| 参数名      | 参数类型     | 参数说明 | 是否消耗gas |
| ----------- | ------------ | -------- | ----------- |
| interfaceId | bytes4字符串 | 合约接口 | 否          |

请求示例

```json
{
    "node": "192.168.3.6:37101",
    "bc_name": "matrixchain",
    "mnemonic": "swap speed jealous region wish together job suit maid company help hunt autumn monster put goose gas link",
    "contract_name":"t1155",
    "module_name": "evm",
    "method_name":"supportsInterface",
    "args":{
        "interfaceId": "0x0e89341c"
    },
    "query": true
}
```

响应示例

```json
// 示例1 interfaceId: ""
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"false\"}]"
    }
}
// 示例2 interfaceId: "0xd9b67a26"(erc165)/"0x0e89341c"(erc1155Metadata_URI)
{
    "code": 200,
    "msg": "查询成功",
    "resp": {
        "data": "[{\"0\":\"true\"}]"
    }
}
```
