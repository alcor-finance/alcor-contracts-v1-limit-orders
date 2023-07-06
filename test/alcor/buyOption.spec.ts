import { Decimal } from 'decimal.js'
import { BigNumber, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from '../shared/expect'

import { TokenERC20 } from '../../typechain/TokenERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { MockAlcorPoolCallOption } from '../../typechain/MockAlcorPoolCallOption'

import { delay, tickToPrice } from '../shared/utils'
import { formatTokenAmount } from '../shared/format'

import { mumbaiUSDC2, mumbaiWETH2 } from '../constants'

import {
    Tokens, deployTokensFixture,
    loadTokensFixture, FactoryFixture,
    createAlcorPoolCallOption,
    loadAlcorPoolCallOptionContract
} from '../shared/fixtures'


Decimal.config({ toExpNeg: -500, toExpPos: 500 })

const AlcorPoolsParams = [{
    isCallOption: true,
    optionExpiration: "1695978000",
    optionStrikePrice: ethers.utils.parseEther("2200")
}]

// deposits in token1
// const DEPOSITS = [
//     {
//         owner: "0x3ee3C1f64FcD409708104DDB84C4aC8F682cE74C", // dev1
//         amount: ethers.utils.parseEther("25"),
//         token: "token1",
//         // tokenAddress: TOKENS[1]
//     }, {
//         owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev2
//         amount: ethers.utils.parseEther("150"),
//         token: "token1",
//         // tokenAddress: TOKENS[1]
//     }
// ]

const SELLING_LIMIT_ORDERS = [
    {
        owner: "0x3ee3C1f64FcD409708104DDB84C4aC8F682cE74C", // dev 1
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "50000",
        deadline: "1685542239274"
    },
    {
        owner: "0x3ee3C1f64FcD409708104DDB84C4aC8F682cE74C", // dev 1
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "51000",
        deadline: "1680000000000"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "52000",
        deadline: "1680000000100"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "53000",
        deadline: "1680000000100"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "54000",
        deadline: "1680000000100"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "55000",
        deadline: "1680000000100"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "56000",
        deadline: "1680000000100"
    }, {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "57000",
        deadline: "1680000000100"
    }, {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "58000",
        deadline: "1680000000100"
    },
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev 2
        for_buying: false,
        contracts_amount: ethers.utils.parseEther("10"),
        premiumTick: "59000",
        deadline: "1680000000100"
    },
]


describe('AlcorPoolCallOptions buyOption tests', () => {
    let accountsLength: number = 3
    let account1: Wallet, account2: Wallet, account3: Wallet
    let token0Addr: string, token1Addr: string
    // token0Addr = mumbaiUSDC2
    // token1Addr = mumbaiWETH2

    let factory: AlcorFactory
    let mock_alcor_pool_call_option_address: string
    const { isCallOption, optionExpiration, optionStrikePrice } = AlcorPoolsParams[0];

    // let loadFixture: ReturnType<typeof createFixtureLoader>
    before("load wallets", async () => {
        [account1, account2, account3] = await (ethers as any).getSigners()
        // accounts = await (ethers as any).getSigners()
        console.log(account1.address, account2.address, account3.address)
    })

    before("deploy tokens", async () => {
        [token0Addr, token1Addr] = await deployTokensFixture()
        let deployer: Wallet = account1
        let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, deployer)
        console.log("token0:", token0.address)
        console.log("token1:", token1.address)
    })

    // console.log(accounts)

    for (let i = 0; i < accountsLength; i++) {
        before("mint tokens to acc1, acc2 and acc3", async () => {
            let accounts = [account1, account2, account3]

            let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, accounts[i])

            let tx0 = await token0.mintToAddress(accounts[i].address, BigNumber.from(2).pow(100).toString())
            await tx0.wait();
            let tx1 = await token1.mintToAddress(accounts[i].address, BigNumber.from(2).pow(100).toString())
            await tx1.wait();
            console.log('i=', i, '; tokens minted')

        })
    }



    before('deploy factory', async () => {
        factory = await FactoryFixture()
        console.log('factory address', factory.address)
    })

    before('create alcor pool for call options', async () => {
        let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, account1)
        mock_alcor_pool_call_option_address = await createAlcorPoolCallOption(factory, token0, token1, optionExpiration, optionStrikePrice)

        console.log('mock_alcor_pool_call_option', mock_alcor_pool_call_option_address)
    })

    for (let i = 0; i < accountsLength; i++) {
        before("approve tokens to alcor pool contract", async () => {
            let accounts = [account1, account2, account3]
            let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, accounts[i])

            let tx0 = await token0.approve(mock_alcor_pool_call_option_address, BigNumber.from(2).pow(150).toString())
            await tx0.wait();
            let tx1 = await token1.approve(mock_alcor_pool_call_option_address, BigNumber.from(2).pow(150).toString())
            await tx1.wait();

            console.log('i=', i, '; tokens approved')
        })
    }



    // for (const deposit of DEPOSITS) {
    //     it(`deposit ${formatTokenAmount(deposit.amount)} of ${deposit.token}`, async () => {
    //         let sender: Wallet
    //         (deposit.owner == account1.address) ? sender = account1 : sender = account2
    //         let mock_alcor_pool_call_option: MockAlcorPoolCallOption = await loadAlcorPoolCallOptionContract(
    //             mock_alcor_pool_call_option_address,
    //             sender)
    //         let { token, amount } = deposit
    //         let tokenAddress = (token == 'token0') ? token0Addr : token1Addr
    //         let tx = await mock_alcor_pool_call_option.deposit(tokenAddress, amount)
    //         await tx.wait()
    //     })
    // }

    let signatures: string[] = []
    describe('buy option', () => {
        for (const selling_limit_order of SELLING_LIMIT_ORDERS) {
            it('get signatures of selling limit orders', async () => {
                let viewer: Wallet = account3
                let mock_alcor_pool_call_option: MockAlcorPoolCallOption = await loadAlcorPoolCallOptionContract(
                    mock_alcor_pool_call_option_address,
                    viewer)
                let hash = await mock_alcor_pool_call_option.getSellingLimitOrderHash(selling_limit_order)
                console.log("hash", hash)
                // let MetamaskHash = await mock_alcor_pool_call_option.getEthSignedMessageHash(hash)
                // console.log('MetamaskHash', MetamaskHash)

                let signature: string
                if (selling_limit_order.owner == account1.address) {
                    signature = await account1.signMessage(ethers.utils.arrayify(hash))
                    signatures.push(signature)
                    console.log(signature)
                } else if (selling_limit_order.owner == account2.address) {
                    signature = await account2.signMessage(ethers.utils.arrayify(hash))
                    signatures.push(signature)
                    console.log(signature)
                }
            })
        }
        it('now buying option', async () => {
            await delay(5)
            // console.log('signatures', signatures)

            let buyOptionInput = {
                amountToBuy: ethers.utils.parseEther("150"),
                signatures: signatures,
                sellingLimitOrders: [] as any,
            }

            for (const selling_limit_order of SELLING_LIMIT_ORDERS) {
                buyOptionInput.sellingLimitOrders.push([
                    0,
                    0,
                    0,
                    0,
                    selling_limit_order.owner,
                    selling_limit_order.contracts_amount,
                    selling_limit_order.premiumTick,
                    selling_limit_order.deadline
                ])
            }
            console.log('buyOptionInput')
            console.log(buyOptionInput)

            let sender: Wallet = account3
            let mock_alcor_pool_call_option: MockAlcorPoolCallOption = await loadAlcorPoolCallOptionContract(
                mock_alcor_pool_call_option_address,
                sender)

            let res = await mock_alcor_pool_call_option.buyOption(buyOptionInput.amountToBuy, buyOptionInput.signatures, buyOptionInput.sellingLimitOrders)
            // console.log(res)
        })
        it("checking balances of users", async () => {
            await delay(5)

            let users: Wallet[] = [account1, account2, account3]
            let viewer: Wallet = account3
            let mock_alcor_pool_call_option: MockAlcorPoolCallOption = await loadAlcorPoolCallOptionContract(
                mock_alcor_pool_call_option_address,
                viewer)
            for (const user of users) {
                let res = await mock_alcor_pool_call_option.usersInfo(user.address)
                console.log('user', user.address)
                console.log('token0_totalDeposits', res.token0_totalDeposits.toString())
                console.log('token1_totalDeposits', res.token1_totalDeposits.toString())
                console.log('soldContractsAmount', res.soldContractsAmount.toString())
                console.log('token1_lockedAmount', res.token1_lockedAmount.toString())
                console.log('------------------')
            }
        })
    })
})


