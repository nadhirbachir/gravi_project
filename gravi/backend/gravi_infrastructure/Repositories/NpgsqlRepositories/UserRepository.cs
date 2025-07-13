using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class UserRepository : NpgsqlRepositoryBase<UserRepository>, IUserRepository
    {
        public UserRepository(DbConnection connection, DbTransaction? transaction, ILogger<UserRepository> logger) : base(connection, transaction, logger) { }


        public async Task<(string Message, long? Result)> AddUser(User newUser)
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
                if(long.TryParse(result?.ToString(), out long newId))
                {
                    return MapAddUserResult(newId);
                }
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

            return ("Something went wrong", null);
        }

        public async Task<(string Message, bool Result)> UpdateUser(User user)
        {
            throw new NotImplementedException();
        }

        public async Task<(string Message, bool Result)> DeleteUser(long userId, string passwordHash)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> FindUserById(long userId)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> FindUserByPersonId(long personId)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> FindUserByEmail(string email)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> FindUserByUsername(string username)
        {
            throw new NotImplementedException();
        }

        public async Task<User?> LogUser(string usernameOrEmail, string password)
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
    }
}
