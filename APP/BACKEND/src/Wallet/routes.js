const express = require('express');
const router = express.Router();
const controllers = require("./controllers.js")
const database = require('../../db');

// Route to fetch user wallet balance
router.post('/FetchWalletBalance', async (req, res) => {
    try {
        await controllers.FetchWalletBalance(req, res);
    } catch (error) {
        console.error('Error in FetchWalletBalance route:', error);
        res.status(500).json({ message: 'Internal Server Error' });
    }
});


//PHONE PAY Route 
const Razorpay = require('razorpay');
const razorpay = new Razorpay({
    key_id: 'rzp_live_62NvZ13QGMQk1S',
    key_secret: '197TCzFTZb7QI3TW1xaLXTmT'
});

router.post('/createOrder', async (req, res) => {
    try {
        const { userId } = req.body;
        const db = await database.connectToDatabase();
        const usersCollection = db.collection("users");
        const getUserDetails = await usersCollection.findOne({ user_id: userId, status: true });
        
        if (!getUserDetails) {
            return res.status(404).json({ message: 'Your account has been deactivated. Please contact the admin.' });
        }

        const options = {
            amount: Math.round(req.body.amount * 100), // amount in the smallest currency unit
            currency: req.body.currency,
        };

        const response = await razorpay.orders.create(options);
        res.json(response);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});
router.post('/savePayments', async (req, res) => {
    try {
        const result = await controllers.savePaymentDetails(req.body);
        if (result === true) {
            res.json(1);
        } else {
            res.json(0);
        }
    } catch (error) {
        console.log(error);
    }
});

//Route to Fetch specific user wallet deduction and wallet recharge history
router.post('/getTransactionDetails', async function(req, res) {
    try {
        const { username } = req.body;

        if (!username) {
            const errorMessage = 'TransactionDetails - Username undefined!';
            return res.status(401).json({ message: errorMessage });
        }

        const { success, data, message } = await controllers.getTransactionDetails(username);
        if (success) {
            return res.status(200).json({ value: data });
        } else {
            return res.status(500).json({ message: message });
        }

    } catch (error) {
        console.error('Error in getTransactionDetails route:', error);
        res.status(500).json({ message: 'Internal Server Error' });
    }
});

// Export the router
module.exports = router;