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
using Npgsql;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class CountryRepository : NpgsqlRepositoryBase, ICountryRepository
    {
        public CountryRepository(NpgsqlConnection connection, NpgsqlTransaction? transaction) : base(connection, transaction) { }

        public async Task<Country?> FindByName(string name)
        {
            string sql = "SELECT * FROM get_country_by_name(@name);";
            var cmd = new NpgsqlCommand(sql, Connection, Transaction);
            cmd.Parameters.AddWithValue("name", name);
            await using var reader = await cmd.ExecuteReaderAsync();
            if(await reader.ReadAsync())
            {
                return MapCountryFromReader(reader);
            }
            return null;
        }

        public async Task<Country?> FindById(int id)
        {
            
            const string sql = "SELECT * FROM get_country_by_id(@id);";

            await using var cmd = new NpgsqlCommand(sql, Connection, Transaction)
            {
                Parameters = { new NpgsqlParameter("id", id) }
            };

            await using var reader = await cmd.ExecuteReaderAsync();
            return await reader.ReadAsync() ? MapCountryFromReader(reader) : null;
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
