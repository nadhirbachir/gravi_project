using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Data.Extensions;
using gravi_infrastructure.Repositories.Base;
using gravi_infrastructure.Repositories.Utilities;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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
            if (user == null) return ("Parameters Error, can't update the user.", false);

            const string sql = "SELECT update_user_by_id(@user_id, @username, @phone_number, @email);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("user_id", user.UserId),
                    new NpgsqlParameter("username", user.Username),
                    new NpgsqlParameter("phone_number", user.PhoneNumber),
                    new NpgsqlParameter ("email", user.Email)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if (int.TryParse(result?.ToString(), out int resultCode))
                {
                    return resultCode switch
                    {
                        > 0 => ("User updated successfuly", true),
                        -1 => ("Person Id not found", false),
                        -2 => ("username already exists", false),
                        -3 => ("username length, or email/phone formats are wrong", false),
                        _ => ("something went wrong", false)
                    };
                }
                else
                    return ("something went wrong", false);
            }
            catch(NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return ("something went wrong", false);
            }
            catch(Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return ("something went wrong", false);
            }

        }

        private async Task<bool> CheckPassword(long? userId, string? password)
        {
            if(userId == null ||  password == null) return false;

            const string sql = "SELECT get_password_hash_by_user_id(@user_id);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("user_id", userId.Value)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if (PasswordHasherUtil.Verify(result?.ToString(), password))
                    return true;
                return false;
            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return false;
            }
        }

        public async Task<(string Message, bool Result)> DeleteUserAsync(long? userId, string? passwordHash)
        {
            if(userId == null || passwordHash == null) return ("Parameters Error, can't delete the user.", false);

            if (!await CheckPassword(userId, passwordHash)) return ("User password is incorrect, can't delete the user.", false);

            const string sql = "SELECT delete_user_by_id(@user_id);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("user_id", userId.Value)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();

                if (int.TryParse(result?.ToString(), out int deleted))
                {
                    return MapDeleteUser(deleted);
                }
                else
                    return ("Something went wrong.", false);
            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return ("Something went wrong.", false);
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return ("Something went wrong.", false);
            }


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

            const string sql = "SELECT * FROM get_user_details_by_person_id(@personId);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("personId", personId.Value)
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
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return null;
            }

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
            if (string.IsNullOrEmpty(email)) return null;

            const string sql = "SELECT * FROM get_user_details_by_email(@email);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("email", email)
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
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return null;
            }
        }

        public async Task<User?> FindUserByUsernameAsync(string? username)
        {
            if (string.IsNullOrEmpty(username)) return null;

            const string sql = "SELECT * FROM get_user_details_by_username(@username);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("username", username)
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
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return null;
            }
        }

        public async Task<User?> LogUserAsync(string usernameOrEmail, string password)
        {
            if (string.IsNullOrEmpty(usernameOrEmail) || string.IsNullOrEmpty(password)) return null;

            const string sql = "SELECT * FROM get_user_details_by_username(@username_or_email);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("username_or_email", usernameOrEmail)
                }
            };

            try
            {
                await using var reader = await cmd.ExecuteReaderAsync();

                if (reader.Read())
                {
                    return MapLogUser(reader,  password);
                }
                else return null;


            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected Exception: {ex.Message}");
                return null;
            }
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

        private User? MapLogUser(NpgsqlDataReader reader, string plainPassword)
        {
            if (reader == null) return null;

            string password = reader.Get<string>("password_hash");
            if(!PasswordHasherUtil.Verify(password, plainPassword)) return null;

            return MapFindUserById(reader);
        }

        private (string, bool) MapDeleteUser(int? result)
        {
            return result switch
            {
                > 0 => ("User deleted successfuly.", true),
                0 => ("Unexpected Exception occured.", false),
                -1 => ("User not found to delete.", false),
                -2 => ("Cannot delete due to foreign key constraints.", false),
                _ => ("Something went wrong.", false)
            };
        }
    }
}
