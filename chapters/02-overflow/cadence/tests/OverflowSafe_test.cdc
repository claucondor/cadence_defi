import Test
import "OverflowSafe"

access(all) fun testAddition() {
    let token <- OverflowSafe.createToken(balance: 100.0)

    token.add(amount: 50.0)

    assert(token.balance == 150.0, message: "Balance should be 150.0")

    destroy token
}

access(all) fun testSubtraction() {
    let token <- OverflowSafe.createToken(balance: 100.0)

    token.subtract(amount: 50.0)

    assert(token.balance == 50.0, message: "Balance should be 50.0")

    destroy token
}
