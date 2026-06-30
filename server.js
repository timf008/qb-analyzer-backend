const express = require("express");
const cors = require("cors");
const { execFile } = require("child_process");
const path = require("path");

const app = express();
app.use(cors());

app.get("/run_qb", (req, res) => {
    const qb = req.query.qb;
    const season = req.query.season;

    execFile("Rscript", [path.join(__dirname, "nflreadr.R"), qb, season], (err, stdout, stderr) => {
        if (err) {
            console.error(err);
            return res.json({ error: "Backend execution error" });
        }

        try {
            const json = JSON.parse(stdout);
            res.json(json);
        } catch (e) {
            console.error("JSON parse error:", e);
            res.json({ error: "Invalid JSON from R" });
        }
    });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Backend running on port ${PORT}`));
