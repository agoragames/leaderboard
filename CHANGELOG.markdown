# leaderboard 1.0.1 (in progress)

 * `redis_options` can be passed in the initializer to pass options for the connection to Redis
 * `page_size` is now settable outside of the initializer
 * `check_member?(member)`: Check to see whether member is in the leaderboard
 * `score_and_rank_for(member, use_zero_index_for_rank = false)`: Retrieve the score and rank for a member in a single call
 * `remove_members_in_score_range(min_score, max_score)`: Remove members from the leaderboard within a score range

# leaderboard 1.0.0

 * Initial release
