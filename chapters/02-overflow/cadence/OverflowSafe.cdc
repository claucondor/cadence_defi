// Cadence 1.0 - Overflow/Underflow Protection Native
access(all) contract OverflowSafe {
    
    access(all) resource Token {
        access(all) var balance: UFix64
        
        init(balance: UFix64) {
            self.balance = balance
        }
        
        // Cadence AUTOMATICALLY prevents overflow/underflow
        access(all) fun add(amount: UFix64) {
            self.balance = self.balance + amount  // Revierte si overflow
        }
        
        access(all) fun subtract(amount: UFix64) {
            pre {
                self.balance >= amount: "Insufficient balance"
            }
            self.balance = self.balance - amount  // Revierte si underflow
        }
    }
    
    access(all) fun createToken(balance: UFix64): @Token {
        return <- create Token(balance: balance)
    }
}
