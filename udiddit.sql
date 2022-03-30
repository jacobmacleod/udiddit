-- use SQL DDL to create new database schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(25) UNIQUE NOT NULL,
    last_login DATE
);

ALTER TABLE "users"
    ADD CONSTRAINT "username_not_empty"
    CHECK (LENGTH(TRIM("username")) > 0);

CREATE TABLE topics (
    id SERIAL PRIMARY KEY,
    name VARCHAR(30) UNIQUE NOT NULL,
    description VARCHAR(500) NULL
);

ALTER TABLE "topics"
    ADD CONSTRAINT "topic_name_not_empty"
    CHECK (LENGTH(TRIM("name")) > 0);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    time_created TIMESTAMP WITH TIME ZONE,
    topic_id INTEGER NOT NULL REFERENCES topics ON DELETE CASCADE,
    user_id INTEGER REFERENCES users ON DELETE SET NULL,
    title VARCHAR(100) NOT NULL,
    url TEXT DEFAULT NULL,
    text_content TEXT DEFAULT NULL
);

ALTER TABLE "posts"
    ADD CONSTRAINT "post_title_not_empty"
    CHECK (LENGTH(TRIM("title")) > 0);

ALTER TABLE "posts"
    ADD CONSTRAINT "post_either_link_or_text"
    CHECK (("url" IS NULL AND "text_content" IS NOT NULL)
        OR ("url" IS NOT NULL AND "text_content" IS NULL));

CREATE INDEX ON "posts" ("user_id");

CREATE INDEX ON "posts" ("topic_id");

CREATE INDEX ON "posts" ("url");

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    time_created TIMESTAMP WITH TIME ZONE,
    post_id INTEGER NOT NULL REFERENCES posts ON DELETE CASCADE,
    user_id INTEGER REFERENCES users ON DELETE SET NULL,
    text_content TEXT NOT NULL,
    parent_comment_id INTEGER REFERENCES comments ON DELETE CASCADE
);

CREATE INDEX ON "comments" ("parent_comment_id");

ALTER TABLE "comments"
    ADD CONSTRAINT "comment_not_empty"
    CHECK (LENGTH(TRIM("text_content")) > 0);

CREATE TABLE votes (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts ON DELETE CASCADE,
    user_id INTEGER REFERENCES users ON DELETE SET NULL,
    vote INTEGER
);

CREATE INDEX ON "votes" ("vote");

ALTER TABLE "votes"
    ADD CONSTRAINT "one_vote_per_user" UNIQUE (post_id, user_id);

-- migrate the data to the new schema
INSERT INTO "users" (username)
SELECT "username"
  FROM "bad_posts"
 UNION
SELECT "username"
  FROM "bad_comments"
 UNION
SELECT regexp_split_to_table(upvotes, ',')
  FROM "bad_posts"
 UNION
SELECT regexp_split_to_table(downvotes, ',')
  FROM "bad_posts";

INSERT INTO "topics" (name)
SELECT DISTINCT "topic"
  FROM "bad_posts"
 GROUP BY "topic";

INSERT INTO "posts" (topic_id, user_id, title, url, text_content)
SELECT t.id, u.id, LEFT(bp.title, 100), bp.url, bp.text_content
  FROM "bad_posts" bp
  JOIN "topics" t
    ON bp.topic = t.name
  JOIN "users" u
    ON bp.username = u.username;

INSERT INTO "comments" (post_id, user_id, text_content)
SELECT bc.post_id, u.id, bc.text_content
  FROM "bad_comments" bc
  JOIN "users" u
    ON bc.username = u.username;

INSERT INTO "votes" (post_id, user_id, vote)
SELECT t1.id, u.id, 1 AS vote
  FROM (SELECT id, regexp_split_to_table(upvotes, ',') AS username
          FROM bad_posts) AS t1
  JOIN "users" u
    ON u.username = t1.username;

INSERT INTO "votes" (post_id, user_id, vote)
SELECT t1.id, u.id, -1 AS vote
  FROM (SELECT id, regexp_split_to_table(downvotes, ',') AS username
          FROM bad_posts) AS t1
  JOIN "users" u
    ON u.username = t1.username;
