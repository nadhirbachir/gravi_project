using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Data.Extensions;
using gravi_infrastructure.Repositories.Base;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class UserRepository : NpgsqlRepositoryBase<UserRepository>, IUserRepository
    {
        public UserRepository(DbConnection connection, DbTransaction? transaction, ILogger<UserRepository> logger) : base(connection, transaction, logger) { }


        public async Task<(string Message, long? Result)> AddUserAsync(User newUser)
        {
            const string sql = "SELECT add_user(@person_id, @username, @phone_number, @email, @password_hash);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("person_id", newUser.Person.PersonId),
                    new NpgsqlParameter("username", newUser.Username),
                    new NpgsqlParameter("phone_number", newUser.PhoneNumber),
                    new NpgsqlParameter("email", newUser.Email),
                    new NpgsqlParameter("password_hash", newUser.PasswordHash)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if (long.TryParse(result?.ToString(), out long newId))
                {
                    return MapAddUserResult(newId);
                }
                else
                    return ("User was not added successfuly", null);
            }
            catch(NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex}");
                return ("Something went wrong", null);
            }
            catch(Exception ex)
            {
                Logger.LogError($"Unexpected error occured: {ex}");
                return ("Something went wrong", null);
            }

        }

        public async Task<(string Message, bool Result)> UpdateUserAsync(User user)
        {
            throw new NotImplementedException();
        }

        public async Task<(string Message, bool Result)> DeleteUserAsync(long userId, string passwordHash)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> FindUserByIdAsync(long? userId)
        {
            if (userId == null) return null;

            const string sql = "SELECT * FROM get_user_details_by_id(@userId);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("userId", userId.Value)
                }
            };

            try
            {
                await using var reader = await cmd.ExecuteReaderAsync();

                if (reader.Read())
                {
                    return MapFindUserById(reader);
                }
                else return null;


            }
            catch(NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return null;
            }
            catch(Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return null;
            }

        }

        public async Task<User?> FindUserByPersonIdAsync(long? personId)
        {
            if (personId == null) return null;
            return null;
            
        }

        public async Task<bool> UserExistsByPersonIdAsync(long? personId)
        {
            if (personId == null) return false;
            const string sql = "SELECT user_exists_by_person_id(@personId);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("personId", personId.Value)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if (bool.TryParse(result?.ToString(), out bool exists))
                {
                    return exists;
                }
                else return false;
            }
            catch(NpgsqlException pgex)
            {
                Logger.LogError("Npgsql Exception: " + pgex.Message);
                return false;
            }
            catch(Exception ex)
            {
                Logger.LogError("Unexpected Exception: " + ex.Message);
                return false;
            }

        }

        public async Task<User?> FindUserByEmailAsync(string? email)
        {
            if (!string.IsNullOrEmpty(email)) return null;

            throw new NotImplementedException();
        }

        public async Task<User?> FindUserByUsernameAsync(string? username)
        {
            if (!string.IsNullOrEmpty(username)) return null;

            throw new NotImplementedException();
        }

        public async Task<User?> LogUserAsync(string usernameOrEmail, string password)
        {
            throw new NotImplementedException();
        }



        private (string, long?) MapAddUserResult(long? newId)
        {
            return newId switch
            {
                > 0 => ("User added successfuly.", newId),
                -1 => ("Person not found", null),
                -2 => ("Username, email, or person already exists.", null),
                -3 => ("Username length, email format, or phone format problem.", null),
                _ => ("Something went wrong.", null)
            };
        }

        private User? MapFindUserById(NpgsqlDataReader reader)
        {
            if (reader == null) return null;


            return new User
            {
                UserId = reader.Get<long>("user_id"),
                Person = new Person
                {
                    PersonId = reader.Get<long>("person_id"),
                    FirstName = reader.Get<string>("first_name"),
                    MiddleName = reader.Get<string>("middle_name"),
                    LastName = reader.Get<string>("last_name"),
                    Country = new Country
                    {
                        CountryId = reader.Get<int>("country_id"),
                        CountryName = reader.Get<string>("country_name")
                    },
                    DateOfBirth = reader.Get<DateTime>("date_of_birth"),
                    Gender = (gravi_domain.Enums.GenderType)reader.Get<short>("gender")
                },
                Username = reader.Get<string>("username"),
                PhoneNumber = reader.Get<string>("phone_number"),
                Email = reader.Get<string>("email"),
                IsEmailVerified = reader.Get<bool>("is_email_verified"),
                Status = (User.UserStatus)reader.Get<short>("status")
            };
        }
    }
}
