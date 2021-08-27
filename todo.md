
- Add User.log_info method

- Add stats update for `files`, store as counters in PG and update once for every ten requests
- Store user with token user_id:token
- Use fs as blocks of 1000 users to limit shared space too much
- replace get_optional with fget