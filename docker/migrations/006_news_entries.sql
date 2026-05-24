-- Blog/news entries for the homepage
CREATE TABLE IF NOT EXISTS news_entries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    subject VARCHAR(255) NOT NULL,
    author VARCHAR(64) NOT NULL DEFAULT 'moot',
    body TEXT NOT NULL,
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created (created)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed blog posts for a freshly launched instance
INSERT INTO news_entries (subject, author, body, created) VALUES
(
    'Welcome to 4chan',
    'moot',
    'Welcome to our restored instance of 4chan, running the original Yotsuba engine. This site has been rebuilt from the leaked source code as a preservation and research project.\n\nAll boards are active and ready for posting. No registration is required -- just pick a board and start posting. Image uploads are enabled on all boards.\n\nThis is a local-first deployment. Everything runs on your machine, nothing phones home, and the full source is available for inspection. Have fun.',
    NOW() - INTERVAL 2 HOUR
),
(
    'Rules',
    'moot',
    'The global rules are simple:\n\n1. You will not upload, post, discuss, request, or link to anything that violates local or United States law.\n2. You will immediately cease and not continue to access the site if you are under the age of 18.\n3. You will not post or request personal information or calls to invasion.\n4. No spamming or flooding of any kind.\n5. No malicious content or virus links.\n6. Advertising (all forms) is not welcome.\n\nIndividual boards may have additional rules posted in their sticky threads. Violating the rules will result in post deletion and may result in a ban.\n\nRemember: the quality of posts is extremely important to this community. Contributors are encouraged to provide high-quality images and informative comments.',
    NOW() - INTERVAL 1 HOUR
),
(
    'Technical Notes: Yotsuba Restoration',
    'moot',
    'Some technical details about this restoration for those interested:\n\n- <b>Engine:</b> Original Yotsuba PHP engine, patched for PHP 8.x compatibility\n- <b>Database:</b> MariaDB 10.1, schema-compatible with the original MySQL setup\n- <b>Boards:</b> All 84 boards from the original boardlist are active\n- <b>Features:</b> Posting, image uploads, tripcodes, capcodes, catalog view, thread archiving\n- <b>Disabled:</b> CAPTCHA, GeoIP, ad scripts, external CDN dependencies, rate limiting (relaxed for testing)\n\nThe cascading config system (global &rarr; category &rarr; board INI files) is preserved. The original admin panel is accessible at <a href="/admin">/admin</a> from local IPs.\n\nThis is release <b>0.1.3.3.7</b> of Jeffrey''s Island Adventure. Built by a former 99chan admin. Local-first, agent-ready, anonymous forever.',
    NOW()
);
