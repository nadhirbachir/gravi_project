using Microsoft.Extensions.Logging;
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
        private readonly ILogger _logger;

        protected RepositoryBase (DbConnection connection, DbTransaction? transaction, ILogger logger)
        {
            _connection = connection ?? throw new ArgumentNullException(nameof(connection), "connection can't be null.");
            _transaction = transaction;
            _logger = logger ?? throw new ArgumentNullException(nameof(logger), "Logger can't be null.");
        }

        protected virtual DbConnection Connection => _connection;
        protected virtual DbTransaction? Transaction => _transaction;
        protected virtual ILogger Logger => _logger;

    }
}
