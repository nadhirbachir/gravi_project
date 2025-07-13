using Microsoft.Extensions.Logging;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Repositories.Base
{
    public abstract class NpgsqlRepositoryBase<T> : RepositoryBase
    {
        protected NpgsqlRepositoryBase(DbConnection connection, DbTransaction? transaction, ILogger<T> logger) : base(connection, transaction, logger)
        {
            if (connection is not NpgsqlConnection) throw new ArgumentException(nameof(connection), "Connection is not NpgsqlConnection.");
            if (transaction != null && transaction is not NpgsqlTransaction) throw new ArgumentException(nameof(transaction), "Transaction is not NpgsqlTransaction.");
        }


        protected override NpgsqlConnection Connection => (NpgsqlConnection)base.Connection;
        protected override NpgsqlTransaction? Transaction => (NpgsqlTransaction?)base.Transaction;
        protected override ILogger<T> Logger => (ILogger<T>)base.Logger;
    }
}
