EXPLAIN ANALYZE
SELECT * FROM mechanics
WHERE salary >= 60000;

CREATE MATERIALIZED VIEW high_paid_mechanics_mv AS
SELECT *
FROM mechanics
WHERE salary >= 60000;

EXPLAIN ANALYZE
SELECT * FROM high_paid_mechanics_mv
where experience = 10

CREATE INDEX idx_high_paid_experience ON high_paid_mechanics_mv(experience);

ANALYZE high_paid_mechanics_mv;

EXPLAIN ANALYZE
SELECT * FROM high_paid_mechanics_mv
WHERE experience = 10;


