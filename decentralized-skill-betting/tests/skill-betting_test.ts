import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that users can create games",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("skill-betting", "create-game", [
                types.ascii("puzzle-game"),
                types.uint(1000),
                types.uint(4)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        
        block.receipts[0].result.expectOk().expectUint(1);
    },
});

Clarinet.test({
    name: "Ensure that users can join games",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;
        
        // First create a game
        let block = chain.mineBlock([
            Tx.contractCall("skill-betting", "create-game", [
                types.ascii("puzzle-game"),
                types.uint(1000),
                types.uint(4)
            ], deployer.address)
        ]);
        
        // Then join the game
        block = chain.mineBlock([
            Tx.contractCall("skill-betting", "join-game", [
                types.uint(1)
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectBool(true);
    },
});