<?php

use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../../lib/source_attachment.php';
require_once __DIR__ . '/../../lib/voting.php';
require_once __DIR__ . '/../../lib/word_filtering.php';

class FeatureHelpersTest extends TestCase
{
    public function testSourceFilenameIsNormalizedAndValidated(): void
    {
        $metadata = source_attachment_metadata('../Example.PHP', 'txt,php,rs');

        $this->assertSame('Example', $metadata['filename']);
        $this->assertSame('.php', $metadata['ext']);
        $this->assertSame('Example.php', $metadata['display_name']);
    }

    public function testSourceFilenameRejectsDisallowedExtension(): void
    {
        $this->assertNull(source_attachment_metadata('payload.exe', 'txt,rs'));
        $this->assertNull(source_attachment_metadata('no-extension', 'txt,rs'));
    }

    public function testSourceUrlEncodesTheDisplayName(): void
    {
        $this->assertSame(
            '/source/g/42/hello%20world.rs',
            source_attachment_url('g', 42, 'hello world.rs')
        );
    }

    public function testSourceBinaryDataPreservesEmptyAndStreamValues(): void
    {
        $stream = fopen('php://temp', 'r+');
        fwrite($stream, "source\0data");
        rewind($stream);

        $this->assertSame('', source_attachment_data(''));
        $this->assertSame("source\0data", source_attachment_data($stream));
        $this->assertNull(source_attachment_data(null));

        fclose($stream);
    }

    public function testVoteDirectionIsAllowlisted(): void
    {
        $this->assertSame('upvotes', vote_direction_column('up'));
        $this->assertSame('downvotes', vote_direction_column('down'));
        $this->assertNull(vote_direction_column('sideways'));
    }

    public function testVoteHashIsDeterministicAndSalted(): void
    {
        $first = vote_voter_hash('192.0.2.1', 'salt-a');
        $this->assertSame($first, vote_voter_hash('192.0.2.1', 'salt-a'));
        $this->assertNotSame($first, vote_voter_hash('192.0.2.1', 'salt-b'));
        $this->assertNotSame($first, vote_voter_hash('192.0.2.2', 'salt-a'));
    }

    public function testInvalidWordFilterTimingFallsBackToStore(): void
    {
        if (!defined('WORD_FILT_TIMING')) {
            define('WORD_FILT_TIMING', 'invalid');
        }

        $this->assertSame('store', word_filter_timing());
    }
}
