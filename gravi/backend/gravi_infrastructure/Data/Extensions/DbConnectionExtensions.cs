using System;
using System.Collections.Generic;
using System.Data;              // for IDbConnection
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;                   // For NpgsqlConnection
using Microsoft.Data.SqlClient; // For SqlConnection
using MySql.Data.MySqlClient;   // For MySqlConnection

namespace gravi_infrastructure.Data.Extensions
{
    public static class DbConnectionExtensions
    {
        public static async Task OpenAsync(this IDbConnection connection)
        {
            if (connection is NpgsqlConnection npgsqlConnection) // For PostgreSQL
            {
                await npgsqlConnection.OpenAsync();
            }
            else if (connection is SqlConnection sqlConnection) // For Microsoft SQL Server
            {
                await sqlConnection.OpenAsync();
            }
            else if (connection is MySqlConnection mySqlConnection) // For MySQL
            {
                await mySqlConnection.OpenAsync();
            }
            else
            {
                throw new NotSupportedException("Asynchronous open is not supported for this database connection.");
            }
        }

        public static async Task CloseAsync(this IDbConnection connection)
        {
            if (connection is NpgsqlConnection npgsqlConnection) // For PostgreSQL
            {
                await npgsqlConnection.CloseAsync();
            }
            else if (connection is SqlConnection sqlConnection) // For Microsoft SQL Server
            {
                await sqlConnection.CloseAsync();
            }
            else if (connection is MySqlConnection mySqlConnection) // For MySQL
            {
                await mySqlConnection.CloseAsync();
            }
            else
            {
                throw new NotSupportedException("Asynchronous close is not supported for this database connection.");
            }
        }
    }
}
