<?php

function vote_direction_column(string $direction): ?string
{
    return match ($direction) {
        'up' => 'upvotes',
        'down' => 'downvotes',
        default => null,
    };
}

function vote_voter_hash(string $ip, string $salt): string
{
    return hash_hmac('sha256', "post-vote\0" . $ip, $salt);
}

function vote_json_response(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=UTF-8');
    header('Cache-Control: no-store');
    die(json_encode($payload, JSON_UNESCAPED_SLASHES));
}
