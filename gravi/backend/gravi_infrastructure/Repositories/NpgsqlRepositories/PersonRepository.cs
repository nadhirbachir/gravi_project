using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Data.Extensions;
using gravi_infrastructure.Repositories.Base;
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
    public class PersonRepository : NpgsqlRepositoryBase<PersonRepository>, IPersonRepository
    {
        public PersonRepository(DbConnection connection, DbTransaction? transaction, ILogger<PersonRepository> logger) : base(connection, transaction, logger) { }

        public async Task<(string Message, long? Result)> AddPersonAsync(Person newPerson)
        {
            const string sql = "SELECT add_person(@first_name, @middle_name, @last_name, @country_id, @date_of_birth::DATE, @gender);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("first_name", newPerson.FirstName),
                    new NpgsqlParameter("middle_name", newPerson.MiddleName),
                    new NpgsqlParameter("last_name", newPerson.LastName),
                    new NpgsqlParameter("country_id", newPerson.Country.CountryId),
                    new NpgsqlParameter("date_of_birth", newPerson.DateOfBirth),
                    new NpgsqlParameter("gender", (int)newPerson.Gender)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if (long.TryParse(result?.ToString(), out long newId))
                {
                    return MapAddPersonResult(newId);
                }
            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex.Message}");
                return ("Something went wrong", null);
            }
            catch (Exception ex)
            {
                Logger.LogError($"Unexpected error occured: {ex.Message}");
                return ("Something went wrong", null);
            }

            return ("Something went wrong", null);
        }

        public async Task<(string Message, bool Result)> DeletePersonAsync(long? personId)
        {
            throw new NotImplementedException();
        }

        public async Task<Person?> FindPersonByIdAsync(long? personId)
        {
            const string sql = "SELECT * FROM get_person_by_id(@person_id);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("person_id", personId)
                }
            };

            try
            {
                await using var result = await cmd.ExecuteReaderAsync();
                if (await result.ReadAsync())
                {
                    return MapFindPersonById(result);
                }
                else
                    return null;
            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"{pgex.Message}");
                return null;
            }
            catch(Exception  ex)
            {
                Logger.LogError($"{ex.Message}");
                return null;
            }

        }

        public async Task<bool> PersonExistsAsync(long? personId)
        {
            const string sql = "SELECT person_exists(@person_id);";
            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters =
                {
                    new NpgsqlParameter("person_id", personId)
                }
            };

            try
            {
                object? result = await cmd.ExecuteScalarAsync();
                if(bool.TryParse(result?.ToString(), out bool exists))
                {
                    return exists;
                }
                else return false;

            }
            catch (NpgsqlException pgex)
            {
                Logger.LogError($"{pgex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                Logger.LogError($"{ex.Message}");
                return false;
            }
        }

        public async Task<(string Message, bool Result)> UpdatePersonAsync(Person person)
        {
            throw new NotImplementedException();
        }


        private (string Message, long? Result) MapAddPersonResult(long? personId)
        {
            return personId switch
            {
                > 0 => ("Person added successfuly", personId),
                -1 => ("Error occured, person didn't have valid data.", null),
                _ => ("Something went wrong.", null)
            };
        }

        private Person? MapFindPersonById(NpgsqlDataReader reader)
        {
            if(reader == null) return null;

            return new Person
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
            };
        }
    }
}
