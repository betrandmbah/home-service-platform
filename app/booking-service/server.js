const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const morgan = require("morgan");

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan("combined"));

const bookings = [{"id":101,"customer":"John Client","service":"House Cleaning","date":"2026-05-01"}];

app.get("/health", (req, res) => res.status(200).json({ service: "booking-service", status: "ok" }));
app.get("/bookings", (req, res) => res.json(bookings));
app.post("/bookings", (req, res) => {
  const booking = { id: Date.now(), ...req.body };
  bookings.push(booking);
  res.status(201).json(booking);
});

app.listen(3000, "0.0.0.0", () => console.log("booking-service running on port 3000"));
