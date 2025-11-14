import Test
import "OverflowSafe"

access(all) fun testAddition() {
    let token <- OverflowSafe.createToken(balance: 100.0)
    
    token.add(amount: 50.0)
    
    Test.assertEqual(150.0, token.balance)
    
    destroy token
}

access(all) fun testSubtraction() {
    let token <- OverflowSafe.createToken(balance: 100.0)
    
    token.subtract(amount: 50.0)
    
    Test.assertEqual(50.0, token.balance)
    
    destroy token
}
