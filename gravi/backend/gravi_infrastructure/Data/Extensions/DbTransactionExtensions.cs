using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;
using Microsoft.Data.SqlClient;
using MySql.Data.MySqlClient;
using System.Data;

namespace gravi_infrastructure.Data.Extensions
{
    public static class DbTransactionExtensions
    {
        public static async Task BeginTransactionAsync(this IDbTransaction dbTransaction)
        {
            if(dbTransaction is NpgsqlTransaction npgsqlTransaction)
            {
                await npgsqlTransaction.BeginTransactionAsync();
            }
            else if (dbTransaction is SqlTransaction sqlTransaction)
            {
                await sqlTransaction.BeginTransactionAsync();
            }
            else if (dbTransaction is MySqlTransaction mysqlTransaction)
            {
                await mysqlTransaction.BeginTransactionAsync();
            }
            else
            {
                throw new NotSupportedException("Asynchronous begin transaction is not supported for this database transaction.");
            }
        }

        public static async Task CommitAsync(this IDbTransaction dbTransaction)
        {
            if (dbTransaction is NpgsqlTransaction npgsqlTransaction)
            {
                await npgsqlTransaction.CommitAsync();
            }
            else if (dbTransaction is SqlTransaction sqlTransaction)
            {
                await sqlTransaction.CommitAsync();
            }
            else if (dbTransaction is MySqlTransaction mysqlTransaction)
            {
                await mysqlTransaction.CommitAsync();
            }
            else
            {
                throw new NotSupportedException("Asynchronous commit transaction is not supported for this database transaction.");
            }
        }

        public static async Task RollBackAsync(this IDbTransaction dbTransaction)
        {
            if (dbTransaction is NpgsqlTransaction npgsqlTransaction)
            {
                await npgsqlTransaction.RollBackAsync();
            }
            else if (dbTransaction is SqlTransaction sqlTransaction)
            {
                await sqlTransaction.RollBackAsync();
            }
            else if (dbTransaction is MySqlTransaction mysqlTransaction)
            {
                await mysqlTransaction.RollBackAsync();
            }
            else
            {
                throw new NotSupportedException("Asynchronous rollback transaction is not supported for this database transaction.");
            }
        }

    }
}
