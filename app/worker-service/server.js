const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const morgan = require("morgan");

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan("combined"));

app.get("/health", (req, res) => res.status(200).json({ service: "worker-service", status: "ok" }));
app.get("/workers", (req, res) => res.json([{"id":1,"name":"Mary Cleaner","skill":"Deep cleaning","city":"Hyattsville"},{"id":2,"name":"Sam Electrician","skill":"Electrical repairs","city":"Silver Spring"}]));

app.listen(3000, "0.0.0.0", () => console.log("worker-service running on port 3000"));
