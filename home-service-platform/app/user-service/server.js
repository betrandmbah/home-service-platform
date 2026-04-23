const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const morgan = require("morgan");

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan("combined"));

app.get("/health", (req, res) => res.status(200).json({ service: "user-service", status: "ok" }));
app.get("/users", (req, res) => res.json([{"id":1,"name":"John Client","role":"customer"},{"id":2,"name":"Mary Cleaner","role":"provider"}]));

app.listen(3000, "0.0.0.0", () => console.log("user-service running on port 3000"));
