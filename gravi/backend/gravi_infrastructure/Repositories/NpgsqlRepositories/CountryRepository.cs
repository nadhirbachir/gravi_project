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
    public class CountryRepository : NpgsqlRepositoryBase<CountryRepository>, ICountryRepository
    {
        public CountryRepository(DbConnection connection, DbTransaction? transaction, ILogger<CountryRepository> logger) : base(connection, transaction, logger) { }

        public async Task<Country?> FindByNameAsync(string name)
        {
            const string sql = "SELECT * FROM get_country_by_name(@name);";

            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters = { new NpgsqlParameter("name", name) }
            };

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapCountryFromReader(reader) : null;
        }

        public async Task<Country?> FindByIdAsync(int id)
        {
            
            const string sql = "SELECT * FROM get_country_by_id(@id);";

            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters = { new NpgsqlParameter("id", id) }
            };

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapCountryFromReader(reader) : null;
        }

        public async Task<IEnumerable<Country?>> GetAllCountriesAsync()
        {
            List<Country> countries = new List<Country>();

            const string sql = "SELECT * FROM get_all_countries();";

            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction);

            try
            {
                await using var reader = await cmd.ExecuteReaderAsync();

                while (await reader.ReadAsync())
                {
                    countries.Add(MapCountryFromReader(reader));
                }

                return countries;
            }
            catch(NpgsqlException pgex)
            {
                Logger.LogError($"Npgsql Exception: {pgex}");
                return new List<Country>();
            }
            catch(Exception ex)
            {
                Logger.LogError($"Unexpected error occured: {ex}");
                return new List<Country>();
            }
        }

        public Country? FindByName(string name)
        {
            const string sql = "SELECT * FROM get_country_by_name(@name);";

            using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters = { new NpgsqlParameter("name", name) }
            };

            using var reader = cmd.ExecuteReader();
            return reader.Read() ? MapCountryFromReader(reader) : null;
        }

        public Country? FindById(int id)
        {
            const string sql = "SELECT * FROM get_country_by_id(@id);";

            using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters = { new NpgsqlParameter("id", id) }
            };

            using var reader = cmd.ExecuteReader();
            return reader.Read() ? MapCountryFromReader(reader) : null;
        }

        private Country MapCountryFromReader(NpgsqlDataReader reader)
        {
            return new Country 
            {
                CountryId = reader.Get<int>("country_id"),
                CountryName = reader.Get<string>("name")
            };
        }

    }
}
