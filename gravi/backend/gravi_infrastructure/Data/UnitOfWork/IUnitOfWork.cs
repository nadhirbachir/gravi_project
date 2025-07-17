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
    public interface IUnitOfWork : IDisposable
    {
        DbConnection Connection { get; }
        DbTransaction? Transaction { get; }
        void BeginTransaction();
        void Commit();
        void RollBack();
        new void Dispose();
        public IRepositoryRegistry Registry { get; }
    }
}
