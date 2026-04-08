import { onRequest } from "firebase-functions/v2/https";




export const createSubscriptionV2 = onRequest(
{ region: "us-central1" },
async (req, res) => {
try {
const priceId = req.body.priceId;

const customer = await stripe.customers.create();

const ephemeralKey = await stripe.ephemeralKeys.create(
{ customer: customer.id },
{ apiVersion: "2024-06-20" }
);

const paymentIntent = await stripe.paymentIntents.create({
amount: priceId === "price_1TEvjW2St2PgxIkbdw5dZ5Td" ? 1599 :15999,
currency: "usd",
customer: customer.id,
});

res.json({
clientSecret: paymentIntent.client_secret,
customerId: customer.id,
ephemeralKey: ephemeralKey.secret,
});
} catch (e: any) {
console.error(e);
res.status(500).json({ error: e.message });
}
}
);
