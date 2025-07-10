using gravi_infrastructure.Data.Interfaces;
using gravi_infrastructure.Data.UnitOfWork.RepositoryRegisters;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork
{
    public class UnitOfWork : IUnitOfWork, IUnitOfWorkAsync
    {
        private readonly IDbConnectionFactory _connectionFactory;
        private DbConnection _connection;
        private DbTransaction _transaction;
        private IRepositoryRegistry _registry;

        public UnitOfWork(IDbConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory ?? throw new ArgumentNullException("connection factory can't be null");
        }

        public IDbConnection Connection
        {
            get
            {
                if (_connection == null)
                {
                    _connection = _connectionFactory.CreateConnection();
                    _connection.Open();
                }
                return _connection;
            }
        }

        public IDbTransaction Transaction => _transaction;

        public IRepositoryRegistry Registry => (_registry ??= new NpgsqlRepositoryRegistry(_connection, _transaction));

        public void BeginTransaction()
        {
            if(_connection == null)
            {
                _connection = _connectionFactory.CreateConnection();
            }
            if (_connection.State != ConnectionState.Open)
                _connection.Open();

            _transaction = _connection.BeginTransaction();
        }

        public async Task BeginTransactionAsync()
        {
            if (_connection == null)
            {
                _connection = _connectionFactory.CreateConnection();
            }

            if (_connection.State != ConnectionState.Open)
                await _connection.OpenAsync();

            _transaction = await _connection.BeginTransactionAsync();
        }

        public void Commit()
        {
            if (_transaction == null)
                throw new InvalidOperationException("no valid transaction was initialized.");

            _transaction.Commit();
            _transaction.Dispose();
            _transaction = null;
        }

        public async Task CommitAsync()
        {
            if (_transaction == null)
                throw new InvalidOperationException("no valid transaction was initialized.");

            await _transaction.CommitAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }

        public void RollBack()
        {
            if (_transaction == null)
                throw new InvalidOperationException("No transaction to rollback. Call BeginTransaction first.");
            
            _transaction.Rollback();
            _transaction.Dispose(); // Dispose of the transaction after rollback
            _transaction = null;
        }

        public async Task RollBackAsync()
        {
            if (_transaction == null)
            {
                throw new InvalidOperationException("No transaction to rollback. Call BeginTransactionAsync first.");
            }
            await _transaction.RollbackAsync();
            await _transaction.DisposeAsync(); // Dispose of the transaction after rollback
            _transaction = null;
        }

        public void Dispose()
        {
            if (_transaction != null)
                _transaction.Dispose();

            _transaction = null;

            if (_connection != null && _connection.State == ConnectionState.Open)
            {
                _connection.Close();
                _connection.Dispose();
            }

            _connection = null;


            // Suppress finalization for performance
            GC.SuppressFinalize(this);
        }

        public async Task DisposeAsync()
        {
            if (_connection != null)
                await _transaction.DisposeAsync();

            _transaction = null;

            if(_connection != null && _connection.State == ConnectionState.Open)
            {
                await _connection.CloseAsync();
                await _connection.DisposeAsync();
            }

            _connection = null;

            GC.SuppressFinalize(this);
        }

    }
}
