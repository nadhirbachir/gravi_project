using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Repositories.Base
{
    public abstract class RepositoryBase
    {
        private readonly DbConnection _connection;
        private readonly DbTransaction? _transaction;

        protected RepositoryBase (DbConnection connection, DbTransaction? transaction)
        {
            _connection = connection ?? throw new ArgumentNullException(nameof(connection), "connection can't be null.");
            _transaction = transaction;
        }

        protected virtual DbConnection Connection => _connection;
        protected virtual DbTransaction? Transaction => _transaction;

    }
}
